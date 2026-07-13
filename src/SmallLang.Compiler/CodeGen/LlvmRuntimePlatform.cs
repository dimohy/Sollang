using System.Text;
using SmallLang.Compiler.Diagnostics;

namespace SmallLang.Compiler.CodeGen;

internal abstract class LlvmRuntimePlatform
{
    public abstract string TargetTriple { get; }

    public abstract string EntryPointName { get; }

    public virtual string EntryPointParameters => "";

    public virtual int PointerBitWidth => 64;

    public virtual void EmitGlobals(StringBuilder globals)
    {
    }

    public abstract void EmitExternalDeclarations(StringBuilder functions);

    public abstract void EmitIoPrimitives(StringBuilder functions);

    public abstract void EmitFilePrimitives(StringBuilder functions);

    public abstract void EmitMappedFilePrimitives(StringBuilder functions);

    public abstract void EmitTimePrimitives(StringBuilder functions);

    public abstract void EmitProcessPrimitives(StringBuilder functions);

    public virtual void EmitEnvironmentPrimitives(StringBuilder functions)
    {
    }

    public abstract void EmitEntryHandles(StringBuilder functions);

    public virtual void EmitProcessEntry(StringBuilder functions)
    {
    }

    public virtual bool SupportsHeapAllocation => true;

    public virtual bool SupportsMemoryMapping => true;

    public virtual bool SupportsProcessArguments => true;

    public virtual bool SupportsEnvironment => true;

    public virtual bool SupportsChildProcesses => true;

    public virtual bool SupportsAsync => false;

    public virtual void EmitAsyncPrimitives(StringBuilder functions)
    {
        functions.AppendLine("""
            define internal ptr @smalllang_task_start(ptr %worker, ptr %destroy, ptr %context) #0 {
            entry:
              %control = call ptr @smalllang_alloc(i64 40)
              %allocated = icmp ne ptr %control, null
              br i1 %allocated, label %initialize, label %fail

            initialize:
              %context_slot = getelementptr %smalllang.task_control, ptr %control, i32 0, i32 0
              store ptr %context, ptr %context_slot, align 8
              %resume_slot = getelementptr %smalllang.task_control, ptr %control, i32 0, i32 1
              store ptr %worker, ptr %resume_slot, align 8
              %destroy_slot = getelementptr %smalllang.task_control, ptr %control, i32 0, i32 2
              store ptr %destroy, ptr %destroy_slot, align 8
              %next_slot = getelementptr %smalllang.task_control, ptr %control, i32 0, i32 3
              store ptr null, ptr %next_slot, align 8
              %status_slot = getelementptr %smalllang.task_control, ptr %control, i32 0, i32 4
              store i32 0, ptr %status_slot, align 4
              %state_slot = getelementptr %smalllang.task_control, ptr %control, i32 0, i32 5
              store i32 0, ptr %state_slot, align 4
              %tail = load ptr, ptr @smalllang_task_ready_tail, align 8
              %empty = icmp eq ptr %tail, null
              br i1 %empty, label %first, label %append

            first:
              store ptr %control, ptr @smalllang_task_ready_head, align 8
              br label %queued

            append:
              %tail_next_slot = getelementptr %smalllang.task_control, ptr %tail, i32 0, i32 3
              store ptr %control, ptr %tail_next_slot, align 8
              br label %queued

            queued:
              store ptr %control, ptr @smalllang_task_ready_tail, align 8
              ret ptr %control

            fail:
              ret ptr null
            }

            define internal i1 @smalllang_task_join(ptr %handle) #0 {
            entry:
              br label %poll

            poll:
              %target_status_slot = getelementptr %smalllang.task_control, ptr %handle, i32 0, i32 4
              %target_status = load i32, ptr %target_status_slot, align 4
              %completed = icmp eq i32 %target_status, 2
              br i1 %completed, label %success, label %dequeue

            dequeue:
              %ready = load ptr, ptr @smalllang_task_ready_head, align 8
              %has_ready = icmp ne ptr %ready, null
              br i1 %has_ready, label %run, label %fail

            run:
              %next_slot = getelementptr %smalllang.task_control, ptr %ready, i32 0, i32 3
              %next = load ptr, ptr %next_slot, align 8
              store ptr %next, ptr @smalllang_task_ready_head, align 8
              %became_empty = icmp eq ptr %next, null
              br i1 %became_empty, label %clear_tail, label %invoke

            clear_tail:
              store ptr null, ptr @smalllang_task_ready_tail, align 8
              br label %invoke

            invoke:
              %ready_status_slot = getelementptr %smalllang.task_control, ptr %ready, i32 0, i32 4
              store i32 1, ptr %ready_status_slot, align 4
              %resume_slot = getelementptr %smalllang.task_control, ptr %ready, i32 0, i32 1
              %worker = load ptr, ptr %resume_slot, align 8
              %worker_complete = call i1 %worker(ptr %ready)
              br i1 %worker_complete, label %complete, label %requeue

            complete:
              store i32 2, ptr %ready_status_slot, align 4
              br label %poll

            requeue:
              store i32 0, ptr %ready_status_slot, align 4
              store ptr null, ptr %next_slot, align 8
              %tail = load ptr, ptr @smalllang_task_ready_tail, align 8
              %queue_empty = icmp eq ptr %tail, null
              br i1 %queue_empty, label %requeue_first, label %requeue_append

            requeue_first:
              store ptr %ready, ptr @smalllang_task_ready_head, align 8
              br label %requeued

            requeue_append:
              %tail_next_slot = getelementptr %smalllang.task_control, ptr %tail, i32 0, i32 3
              store ptr %ready, ptr %tail_next_slot, align 8
              br label %requeued

            requeued:
              store ptr %ready, ptr @smalllang_task_ready_tail, align 8
              br label %poll

            success:
              ret i1 true

            fail:
              ret i1 false
            }

            define internal i1 @smalllang_task_release(ptr %handle) #0 {
            entry:
              %status_slot = getelementptr %smalllang.task_control, ptr %handle, i32 0, i32 4
              %status = load i32, ptr %status_slot, align 4
              %completed = icmp eq i32 %status, 2
              br i1 %completed, label %destroy, label %fail

            destroy:
              %destroy_slot = getelementptr %smalllang.task_control, ptr %handle, i32 0, i32 2
              %destroy_fn = load ptr, ptr %destroy_slot, align 8
              %context_slot = getelementptr %smalllang.task_control, ptr %handle, i32 0, i32 0
              %context = load ptr, ptr %context_slot, align 8
              call void %destroy_fn(ptr %context)
              call void @smalllang_free(ptr %handle)
              ret i1 true

            fail:
              ret i1 false
            }

            """);
    }

    public virtual void EmitExitCleanup(StringBuilder functions)
    {
    }

    public virtual void EmitEnvironmentCleanup(StringBuilder functions)
    {
    }

    public abstract void EmitMemoryDeclarations(StringBuilder functions);

    public abstract void EmitMemoryPrimitives(StringBuilder functions);

    public static LlvmRuntimePlatform Create(CompilationTarget target)
    {
        return target switch
        {
            CompilationTarget.WindowsX64 => new WindowsLlvmRuntimePlatform(),
            CompilationTarget.LinuxX64 => new LinuxLlvmRuntimePlatform(),
            CompilationTarget.Wasm32Browser => new WasmBrowserLlvmRuntimePlatform(),
            _ => throw new SmallLangException($"unsupported target '{target}'")
        };
    }
}
