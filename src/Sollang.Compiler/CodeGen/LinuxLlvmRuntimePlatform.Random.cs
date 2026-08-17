using System.Text;

namespace Sollang.Compiler.CodeGen;

internal sealed partial class LinuxLlvmRuntimePlatform
{
    public override void EmitSecureRandomPrimitives(StringBuilder functions)
    {
        functions.AppendLine("declare i64 @getrandom(ptr, i64, i32)");
        functions.AppendLine("""
            define internal i1 @sollang_secure_random_fill(ptr %buffer, i64 %length) #0 {
            entry:
              %empty = icmp eq i64 %length, 0
              br i1 %empty, label %success, label %fill

            fill:
              %offset = phi i64 [ 0, %entry ], [ %next_offset, %continue ]
              %remaining = sub i64 %length, %offset
              %target = getelementptr i8, ptr %buffer, i64 %offset
              %read = call i64 @getrandom(ptr %target, i64 %remaining, i32 0)
              %progress = icmp sgt i64 %read, 0
              br i1 %progress, label %continue, label %failure

            continue:
              %next_offset = add i64 %offset, %read
              %done = icmp eq i64 %next_offset, %length
              br i1 %done, label %success, label %fill

            success:
              ret i1 true

            failure:
              ret i1 false
            }

            """);
    }
}
