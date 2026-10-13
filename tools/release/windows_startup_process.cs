// Native Windows startup containment. No child executes before Job assignment.
using System;
using System.Collections;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading.Tasks;
using Microsoft.Win32.SafeHandles;

public sealed class WindowsStartupProcess : IDisposable {
    [StructLayout(LayoutKind.Sequential)] struct Security { public int Length; public IntPtr Descriptor; public int Inherit; }
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] struct Startup {
        public int Size; public string Reserved, Desktop, Title; public int X,Y,XSize,YSize,XCount,YCount,Fill,Flags;
        public short Show,ReservedSize; public IntPtr ReservedBytes,Input,Output,Error;
    }
    [StructLayout(LayoutKind.Sequential)] struct ProcessInfo { public IntPtr Process,Thread; public int Pid,Tid; }
    [StructLayout(LayoutKind.Sequential)] struct BasicLimit { public long ProcessTime,JobTime; public uint Flags; public UIntPtr Min,Max; public uint Active; public UIntPtr Affinity; public uint Priority,Scheduling; }
    [StructLayout(LayoutKind.Sequential)] struct IoCounters { public ulong ReadOps,WriteOps,OtherOps,ReadBytes,WriteBytes,OtherBytes; }
    [StructLayout(LayoutKind.Sequential)] struct ExtendedLimit { public BasicLimit Basic; public IoCounters Io; public UIntPtr ProcessMemory,JobMemory,PeakProcessMemory,PeakJobMemory; }
    [StructLayout(LayoutKind.Sequential)] struct Accounting { public long User,Kernel,PeriodUser,PeriodKernel; public uint Faults,Total,Active,Terminated; }
    [DllImport("kernel32.dll",SetLastError=true)] static extern IntPtr CreateJobObject(IntPtr attributes,string name);
    [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern IntPtr OpenJobObject(uint access,bool inherit,string name);
    [DllImport("kernel32.dll",SetLastError=true)] static extern bool SetInformationJobObject(IntPtr job,int kind,ref ExtendedLimit value,int size);
    [DllImport("kernel32.dll",SetLastError=true)] static extern bool QueryInformationJobObject(IntPtr job,int kind,out Accounting value,int size,IntPtr length);
    [DllImport("kernel32.dll",SetLastError=true)] static extern bool AssignProcessToJobObject(IntPtr job,IntPtr process);
    [DllImport("kernel32.dll",SetLastError=true)] static extern bool TerminateJobObject(IntPtr job,uint code);
    [DllImport("kernel32.dll",SetLastError=true)] static extern bool CreatePipe(out IntPtr read,out IntPtr write,ref Security security,int size);
    [DllImport("kernel32.dll",SetLastError=true)] static extern bool SetHandleInformation(IntPtr handle,uint mask,uint flags);
    [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern IntPtr CreateFile(string name,uint access,uint share,ref Security security,uint mode,uint flags,IntPtr template);
    [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool CreateProcess(string app,StringBuilder command,IntPtr procAttributes,IntPtr threadAttributes,bool inherit,uint flags,IntPtr environment,string directory,ref Startup startup,out ProcessInfo process);
    [DllImport("kernel32.dll",SetLastError=true)] static extern uint ResumeThread(IntPtr thread);
    [DllImport("kernel32.dll",SetLastError=true)] static extern bool TerminateProcess(IntPtr process,uint code);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
    [DllImport("kernel32.dll",SetLastError=true)] static extern uint WaitForSingleObject(IntPtr handle,uint milliseconds);
    [DllImport("kernel32.dll",SetLastError=true)] static extern bool GetExitCodeProcess(IntPtr process,out uint code);
    IntPtr job,thread,processHandle;
    StreamReader output,error;
    public Process Process {get; private set;}
    public Task<string> Stdout {get; private set;}
    public Task<string> Stderr {get; private set;}
    static void Check(bool ok) { if (!ok) throw new Win32Exception(Marshal.GetLastWin32Error()); }
    static void Close(ref IntPtr value) { if(value!=IntPtr.Zero && value!=new IntPtr(-1)) CloseHandle(value); value=IntPtr.Zero; }
    public WindowsStartupProcess(ProcessStartInfo info,string runToken) {
        IntPtr outRead=IntPtr.Zero,outWrite=IntPtr.Zero,errRead=IntPtr.Zero,errWrite=IntPtr.Zero,input=IntPtr.Zero,env=IntPtr.Zero;
        ProcessInfo child=new ProcessInfo();
        try {
            job=CreateJobObject(IntPtr.Zero,"Local\\MuddsStartup_"+runToken); Check(job!=IntPtr.Zero);
            ExtendedLimit limit=new ExtendedLimit(); limit.Basic.Flags=0x2000; // JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE; no breakaway.
            Check(SetInformationJobObject(job,9,ref limit,Marshal.SizeOf(typeof(ExtendedLimit))));
            Security security=new Security {Length=Marshal.SizeOf(typeof(Security)),Inherit=1};
            Check(CreatePipe(out outRead,out outWrite,ref security,0)); Check(SetHandleInformation(outRead,1,0));
            Check(CreatePipe(out errRead,out errWrite,ref security,0)); Check(SetHandleInformation(errRead,1,0));
            input=CreateFile("NUL",0x80000000,3,ref security,3,0,IntPtr.Zero); Check(input!=new IntPtr(-1));
            List<string> keys=new List<string>(); foreach(string key in info.EnvironmentVariables.Keys) keys.Add(key);
            keys.Sort(StringComparer.OrdinalIgnoreCase);
            StringBuilder block=new StringBuilder(); foreach(string key in keys) block.Append(key).Append('=').Append(info.EnvironmentVariables[key]).Append('\0'); block.Append('\0');
            env=Marshal.StringToHGlobalUni(block.ToString());
            Startup startup=new Startup {Size=Marshal.SizeOf(typeof(Startup)),Flags=0x100,Input=input,Output=outWrite,Error=errWrite};
            // CREATE_SUSPENDED | CREATE_NO_WINDOW | CREATE_UNICODE_ENVIRONMENT.
            Check(CreateProcess(info.FileName,new StringBuilder("\""+info.FileName+"\" "+info.Arguments),IntPtr.Zero,IntPtr.Zero,true,0x08000404,env,info.WorkingDirectory,ref startup,out child));
            Check(AssignProcessToJobObject(job,child.Process));
            Process=Process.GetProcessById(child.Pid);
            processHandle=child.Process; child.Process=IntPtr.Zero;
            thread=child.Thread; child.Thread=IntPtr.Zero;
            output=new StreamReader(new FileStream(new SafeFileHandle(outRead,true),FileAccess.Read)); outRead=IntPtr.Zero;
            error=new StreamReader(new FileStream(new SafeFileHandle(errRead,true),FileAccess.Read)); errRead=IntPtr.Zero;
            Stdout=output.ReadToEndAsync(); Stderr=error.ReadToEndAsync();
        } catch {
            if(child.Process!=IntPtr.Zero) TerminateProcess(child.Process,1);
            Dispose(); throw;
        } finally {
            Close(ref child.Process); Close(ref child.Thread); Close(ref outRead); Close(ref outWrite); Close(ref errRead); Close(ref errWrite); Close(ref input);
            if(env!=IntPtr.Zero) Marshal.FreeHGlobal(env);
        }
    }
    public bool WaitForExit(int milliseconds) { uint state=WaitForSingleObject(processHandle,(uint)milliseconds); if(state==0xFFFFFFFF) throw new Win32Exception(Marshal.GetLastWin32Error()); return state==0; }
    public int ExitCode {get {uint code; Check(GetExitCodeProcess(processHandle,out code)); return unchecked((int)code);}}
    public void Resume() { if(ResumeThread(thread)==0xFFFFFFFF) throw new Win32Exception(Marshal.GetLastWin32Error()); Close(ref thread); }
    public int ActiveProcesses { get { Accounting state; Check(QueryInformationJobObject(job,1,out state,Marshal.SizeOf(typeof(Accounting)),IntPtr.Zero)); return (int)state.Active; } }
    public void Stop(int timeoutMs) {
        Check(TerminateJobObject(job,1));
        Stopwatch watch=Stopwatch.StartNew();
        while(ActiveProcesses!=0 && watch.ElapsedMilliseconds<timeoutMs) System.Threading.Thread.Sleep(20);
        if(ActiveProcesses!=0) throw new TimeoutException("Owned Job processes did not terminate.");
    }
    public bool Drain(int timeoutMs) { return Task.WaitAll(new Task[]{Stdout,Stderr},timeoutMs); }
    public static void Abort(string runToken,string requestPath,int timeoutMs) {
        IntPtr owned=OpenJobObject(0xC,false,"Local\\MuddsStartup_"+runToken); Check(owned!=IntPtr.Zero);
        try {
            Accounting state; Check(QueryInformationJobObject(owned,1,out state,Marshal.SizeOf(typeof(Accounting)),IntPtr.Zero));
            if(state.Active==0) return;
            File.WriteAllText(requestPath,"abort");
            Check(TerminateJobObject(owned,1));
            Stopwatch watch=Stopwatch.StartNew();
            do { Check(QueryInformationJobObject(owned,1,out state,Marshal.SizeOf(typeof(Accounting)),IntPtr.Zero)); if(state.Active==0) return; System.Threading.Thread.Sleep(20); } while(watch.ElapsedMilliseconds<timeoutMs);
            throw new TimeoutException("Owned abort Job did not terminate.");
        } finally { CloseHandle(owned); }
    }
    public void Dispose() {
        // Closing the last Job handle also stops descendants if the harness exits unexpectedly.
        Close(ref job); Close(ref thread); Close(ref processHandle);
        if(output!=null) output.Dispose(); if(error!=null) error.Dispose();
    }
}
