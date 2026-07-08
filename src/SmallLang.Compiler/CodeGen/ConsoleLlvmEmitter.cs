using System.Globalization;
using System.Text;
using SmallLang.Compiler.Diagnostics;
using SmallLang.Compiler.Semantics;
using SmallLang.Compiler.Syntax;

namespace SmallLang.Compiler.CodeGen;

internal sealed class ConsoleLlvmEmitter(BoundProgram program, LlvmRuntimePlatform platform)
{
    private readonly StringBuilder _globals = new();
    private readonly StringBuilder _functions = new();
    private readonly Dictionary<string, RuntimeValue> _locals = new(StringComparer.Ordinal);
    private readonly List<BoundFunction> _inlineFunctionStack = [];
    private RuntimeBlockInvocation? _currentBlockInvocation;
    private IReadOnlyDictionary<string, BoundFunction> _currentFunctions = program.Functions;
    private int _stringId;
    private int _tempId;
    private int _labelId;
    private string _mainOk = "true";
    private string _currentBlockLabel = "entry";

    public string Emit()
    {
        var header = new StringBuilder();
        header.Append("target triple = \"")
            .Append(platform.TargetTriple)
            .AppendLine("\"");
        header.AppendLine();
        header.AppendLine("%smalllang.text = type { ptr, i64 }");
        header.AppendLine("%smalllang.read_int_result = type { i64, i32 }");
        header.AppendLine("%smalllang.file_int_result = type { i64, i32 }");
        header.AppendLine("%smalllang.file_count_result = type { i64, i32 }");
        header.AppendLine();

        platform.EmitGlobals(_globals);
        _globals.AppendLine("@smalllang_random_state = internal global i64 88172645463393265");
        _globals.AppendLine("@smalllang_writer_buffer = internal global [8192 x i64] zeroinitializer, align 8");
        _globals.AppendLine("@smalllang_writer_buffer_count = internal global i64 0");
        _globals.AppendLine();

        platform.EmitExternalDeclarations(_functions);
        _functions.AppendLine();

        EmitUserFunctions();
        EmitRuntimeHelpers();
        EmitMain();
        _functions.AppendLine("attributes #0 = { noinline optnone }");

        return header.ToString() + _globals + _functions;
    }

    private void EmitUserFunctions()
    {
        var emitted = new HashSet<string>(StringComparer.Ordinal);
        foreach (var function in program.Functions.Values)
        {
            if (function.Kind != BoundFunctionKind.User
                || function.IsStandardLibrary
                || function.IsLocal
                || !emitted.Add(function.Name))
            {
                continue;
            }

            switch (function.ReturnType)
            {
                case BoundType.Text:
                    EmitTextFunction(function);
                    break;
                case BoundType.Int:
                    EmitIntFunction(function);
                    break;
                case BoundType.Bool:
                    EmitBoolFunction(function);
                    break;
                default:
                    throw new SmallLangException($"unsupported function return type {function.ReturnType}");
            }
        }
    }

    private void EmitTextFunction(BoundFunction function)
    {
        if (function.Body is null)
        {
            throw new SmallLangException($"function '{function.Name}' has no body");
        }

        var previousFunctions = _currentFunctions;
        _currentFunctions = CreateFunctionScope(program.Functions, function.LocalFunctions);
        _locals.Clear();
        try
        {
            _functions.Append("define internal %smalllang.text ")
                .Append(SymbolForFunction(function.Name))
                .Append('(')
                .Append(ParameterListForFunction(function))
                .AppendLine(") #0 {");
            _functions.AppendLine("entry:");
            BindFunctionParameter(function);

            var value = EmitExpression(function.Body);
            EnsureRuntimeType(value, BoundType.Text, function.Name);
            var text = (RuntimeText)value;
            var aggregate0 = NextTemp("text_ret");
            _functions.Append("  ")
                .Append(aggregate0)
                .Append(" = insertvalue %smalllang.text poison, ptr ")
                .Append(text.PointerName)
                .AppendLine(", 0");
            var aggregate1 = NextTemp("text_ret");
            _functions.Append("  ")
                .Append(aggregate1)
                .Append(" = insertvalue %smalllang.text ")
                .Append(aggregate0)
                .Append(", i64 ")
                .Append(text.LengthName)
                .AppendLine(", 1");
            _functions.Append("  ret %smalllang.text ").AppendLine(aggregate1);
            _functions.AppendLine("}");
            _functions.AppendLine();
        }
        finally
        {
            _currentFunctions = previousFunctions;
        }
    }

    private void EmitIntFunction(BoundFunction function)
    {
        if (function.Body is null)
        {
            throw new SmallLangException($"function '{function.Name}' has no body");
        }

        var previousFunctions = _currentFunctions;
        _currentFunctions = CreateFunctionScope(program.Functions, function.LocalFunctions);
        _locals.Clear();
        try
        {
            _functions.Append("define internal i64 ")
                .Append(SymbolForFunction(function.Name))
                .Append('(')
                .Append(ParameterListForFunction(function))
                .AppendLine(") #0 {");
            _functions.AppendLine("entry:");
            BindFunctionParameter(function);

            var value = EmitIntExpression(function.Body);
            _functions.Append("  ret i64 ").AppendLine(value.ValueName);
            _functions.AppendLine("}");
            _functions.AppendLine();
        }
        finally
        {
            _currentFunctions = previousFunctions;
        }
    }

    private void EmitBoolFunction(BoundFunction function)
    {
        if (function.Body is null)
        {
            throw new SmallLangException($"function '{function.Name}' has no body");
        }

        var previousFunctions = _currentFunctions;
        _currentFunctions = CreateFunctionScope(program.Functions, function.LocalFunctions);
        _locals.Clear();
        try
        {
            _functions.Append("define internal i1 ")
                .Append(SymbolForFunction(function.Name))
                .Append('(')
                .Append(ParameterListForFunction(function))
                .AppendLine(") #0 {");
            _functions.AppendLine("entry:");
            BindFunctionParameter(function);

            var value = EmitBoolExpression(function.Body);
            _functions.Append("  ret i1 ").AppendLine(value.ValueName);
            _functions.AppendLine("}");
            _functions.AppendLine();
        }
        finally
        {
            _currentFunctions = previousFunctions;
        }
    }

    private static string ParameterListForFunction(BoundFunction function)
    {
        return function.InputType switch
        {
            null => "",
            BoundType.Int => "i64 %it",
            BoundType.Bool => "i1 %it",
            _ => throw new SmallLangException("only Int and Bool function input is supported in the current runtime slice")
        };
    }

    private void BindFunctionParameter(BoundFunction function)
    {
        switch (function.InputType)
        {
            case null:
                return;
            case BoundType.Int:
                _locals.Add(function.InputName ?? "it", new RuntimeInt("%it"));
                return;
            case BoundType.Bool:
                _locals.Add(function.InputName ?? "it", new RuntimeBool("%it"));
                return;
            default:
                throw new SmallLangException("only Int and Bool function input is supported in the current runtime slice");
        }
    }

    private void EmitRuntimeHelpers()
    {
        platform.EmitIoPrimitives(_functions);
        platform.EmitFilePrimitives(_functions);
        _functions.AppendLine("""
            define internal i32 @smalllang_write_u64(ptr %stdout, i64 %value, ptr %written) #0 {
            entry:
              %buf = alloca [20 x i8], align 1
              %end = getelementptr inbounds [20 x i8], ptr %buf, i64 0, i64 20
              br label %digits

            digits:
              %n = phi i64 [ %value, %entry ], [ %q, %digits ]
              %p = phi ptr [ %end, %entry ], [ %next, %digits ]
              %digit = urem i64 %n, 10
              %q = udiv i64 %n, 10
              %next = getelementptr i8, ptr %p, i64 -1
              %digit8 = trunc i64 %digit to i8
              %ascii = add i8 %digit8, 48
              store i8 %ascii, ptr %next, align 1
              %done = icmp eq i64 %q, 0
              br i1 %done, label %write, label %digits

            write:
              %start_int = ptrtoint ptr %next to i64
              %end_int = ptrtoint ptr %end to i64
              %len = sub i64 %end_int, %start_int
              %ok = call i32 @smalllang_write(ptr %stdout, ptr %next, i64 %len, ptr %written)
              ret i32 %ok
            }

            define internal %smalllang.read_int_result @smalllang_read_i64(ptr %stdin, ptr %read) #0 {
            entry:
              %buf = alloca [64 x i8], align 1
              %ok = call i32 @smalllang_read_stdin(ptr %stdin, ptr %buf, i64 64, ptr %read)
              %read_ok = icmp ne i32 %ok, 0
              br i1 %read_ok, label %prepare, label %fail

            prepare:
              %read32 = load i32, ptr %read, align 4
              %len = zext i32 %read32 to i64
              br label %skip

            skip:
              %skip_idx = phi i64 [ 0, %prepare ], [ %skip_next, %skip_ws ]
              %skip_has = icmp ult i64 %skip_idx, %len
              br i1 %skip_has, label %skip_char, label %fail

            skip_char:
              %skip_ptr = getelementptr inbounds [64 x i8], ptr %buf, i64 0, i64 %skip_idx
              %skip_ch = load i8, ptr %skip_ptr, align 1
              %skip_sp = icmp eq i8 %skip_ch, 32
              %skip_tab = icmp eq i8 %skip_ch, 9
              %skip_cr = icmp eq i8 %skip_ch, 13
              %skip_lf = icmp eq i8 %skip_ch, 10
              %skip_sp_tab = or i1 %skip_sp, %skip_tab
              %skip_cr_lf = or i1 %skip_cr, %skip_lf
              %skip_is_ws = or i1 %skip_sp_tab, %skip_cr_lf
              br i1 %skip_is_ws, label %skip_ws, label %digit_entry

            skip_ws:
              %skip_next = add i64 %skip_idx, 1
              br label %skip

            digit_entry:
              %first_ge = icmp uge i8 %skip_ch, 48
              %first_le = icmp ule i8 %skip_ch, 57
              %first_digit = and i1 %first_ge, %first_le
              br i1 %first_digit, label %digits, label %fail

            digits:
              %digit_idx = phi i64 [ %skip_idx, %digit_entry ], [ %digit_next, %digit_continue ]
              %value = phi i64 [ 0, %digit_entry ], [ %value_next, %digit_continue ]
              %digit_has = icmp ult i64 %digit_idx, %len
              br i1 %digit_has, label %digit_char, label %success

            digit_char:
              %digit_ptr = getelementptr inbounds [64 x i8], ptr %buf, i64 0, i64 %digit_idx
              %digit_ch = load i8, ptr %digit_ptr, align 1
              %digit_ge = icmp uge i8 %digit_ch, 48
              %digit_le = icmp ule i8 %digit_ch, 57
              %is_digit = and i1 %digit_ge, %digit_le
              br i1 %is_digit, label %digit_continue, label %trail_entry

            digit_continue:
              %digit64 = zext i8 %digit_ch to i64
              %digit_value = sub i64 %digit64, 48
              %value_x10 = mul i64 %value, 10
              %value_next = add i64 %value_x10, %digit_value
              %digit_next = add i64 %digit_idx, 1
              br label %digits

            trail_entry:
              br label %trail

            trail:
              %trail_idx = phi i64 [ %digit_idx, %trail_entry ], [ %trail_next, %trail_ws ]
              %trail_has = icmp ult i64 %trail_idx, %len
              br i1 %trail_has, label %trail_char, label %success

            trail_char:
              %trail_ptr = getelementptr inbounds [64 x i8], ptr %buf, i64 0, i64 %trail_idx
              %trail_ch = load i8, ptr %trail_ptr, align 1
              %trail_sp = icmp eq i8 %trail_ch, 32
              %trail_tab = icmp eq i8 %trail_ch, 9
              %trail_cr = icmp eq i8 %trail_ch, 13
              %trail_lf = icmp eq i8 %trail_ch, 10
              %trail_sp_tab = or i1 %trail_sp, %trail_tab
              %trail_cr_lf = or i1 %trail_cr, %trail_lf
              %trail_is_ws = or i1 %trail_sp_tab, %trail_cr_lf
              br i1 %trail_is_ws, label %trail_ws, label %fail

            trail_ws:
              %trail_next = add i64 %trail_idx, 1
              br label %trail

            success:
              %success_value = phi i64 [ %value, %digits ], [ %value, %trail ]
              %success0 = insertvalue %smalllang.read_int_result poison, i64 %success_value, 0
              %success1 = insertvalue %smalllang.read_int_result %success0, i32 1, 1
              ret %smalllang.read_int_result %success1

            fail:
              %fail0 = insertvalue %smalllang.read_int_result poison, i64 0, 0
              %fail1 = insertvalue %smalllang.read_int_result %fail0, i32 0, 1
              ret %smalllang.read_int_result %fail1
            }

            define internal i32 @smalllang_copy_text_to_c_path(ptr %data, i64 %len, ptr %out) #0 {
            entry:
              %too_long = icmp ugt i64 %len, 259
              br i1 %too_long, label %fail, label %copy

            copy:
              %i = phi i64 [ 0, %entry ], [ %next, %copy_body ]
              %done = icmp eq i64 %i, %len
              br i1 %done, label %nul, label %copy_body

            copy_body:
              %src = getelementptr i8, ptr %data, i64 %i
              %ch = load i8, ptr %src, align 1
              %dst = getelementptr i8, ptr %out, i64 %i
              store i8 %ch, ptr %dst, align 1
              %next = add i64 %i, 1
              br label %copy

            nul:
              %nul_ptr = getelementptr i8, ptr %out, i64 %len
              store i8 0, ptr %nul_ptr, align 1
              ret i32 1

            fail:
              ret i32 0
            }

            define internal i32 @smalllang_seed_random(i64 %seed) #0 {
            entry:
              store i64 %seed, ptr @smalllang_random_state, align 8
              ret i32 1
            }

            define internal %smalllang.file_int_result @smalllang_random_below(i64 %max) #0 {
            entry:
              %valid = icmp sgt i64 %max, 0
              br i1 %valid, label %next, label %fail

            next:
              %state = load i64, ptr @smalllang_random_state, align 8
              %mul = mul i64 %state, 6364136223846793005
              %new_state = add i64 %mul, 1442695040888963407
              store i64 %new_state, ptr @smalllang_random_state, align 8
              %value = urem i64 %new_state, %max
              %ok0 = insertvalue %smalllang.file_int_result poison, i64 %value, 0
              %ok1 = insertvalue %smalllang.file_int_result %ok0, i32 1, 1
              ret %smalllang.file_int_result %ok1

            fail:
              %fail0 = insertvalue %smalllang.file_int_result poison, i64 0, 0
              %fail1 = insertvalue %smalllang.file_int_result %fail0, i32 0, 1
              ret %smalllang.file_int_result %fail1
            }

            define internal i32 @smalllang_open_write_i64_file(ptr %path, i64 %len) #0 {
            entry:
              store i64 0, ptr @smalllang_writer_buffer_count, align 8
              %ok = call i32 @smalllang_platform_open_write_file(ptr %path, i64 %len)
              ret i32 %ok
            }

            define internal i32 @smalllang_flush_i64_file() #0 {
            entry:
              %count = load i64, ptr @smalllang_writer_buffer_count, align 8
              %empty = icmp eq i64 %count, 0
              br i1 %empty, label %success, label %flush

            flush:
              %bytes = mul i64 %count, 8
              %ok = call i32 @smalllang_platform_write_file_bytes(ptr @smalllang_writer_buffer, i64 %bytes)
              %is_ok = icmp ne i32 %ok, 0
              br i1 %is_ok, label %reset, label %fail

            reset:
              store i64 0, ptr @smalllang_writer_buffer_count, align 8
              br label %success

            success:
              ret i32 1

            fail:
              ret i32 0
            }

            define internal i32 @smalllang_write_i64_file(i64 %value) #0 {
            entry:
              %count = load i64, ptr @smalllang_writer_buffer_count, align 8
              %slot = getelementptr inbounds [8192 x i64], ptr @smalllang_writer_buffer, i64 0, i64 %count
              store i64 %value, ptr %slot, align 8
              %next = add i64 %count, 1
              store i64 %next, ptr @smalllang_writer_buffer_count, align 8
              %full = icmp eq i64 %next, 8192
              br i1 %full, label %flush, label %success

            flush:
              %ok = call i32 @smalllang_flush_i64_file()
              ret i32 %ok

            success:
              ret i32 1
            }

            define internal i32 @smalllang_close_write_i64_file() #0 {
            entry:
              %flush_ok = call i32 @smalllang_flush_i64_file()
              %flush_is_ok = icmp ne i32 %flush_ok, 0
              br i1 %flush_is_ok, label %close, label %fail

            close:
              %close_ok = call i32 @smalllang_platform_close_write_file()
              ret i32 %close_ok

            fail:
              ret i32 0
            }

            define internal %smalllang.file_int_result @smalllang_closest_i64_file(i64 %target) #0 {
            entry:
              %count_result = call %smalllang.file_count_result @smalllang_platform_i64_file_count()
              %count = extractvalue %smalllang.file_count_result %count_result, 0
              %count_ok = extractvalue %smalllang.file_count_result %count_result, 1
              %count_is_ok = icmp ne i32 %count_ok, 0
              %has_values = icmp sgt i64 %count, 0
              %can_search = and i1 %count_is_ok, %has_values
              br i1 %can_search, label %search, label %fail

            search:
              br label %loop

            loop:
              %low = phi i64 [ 0, %search ], [ %next_low, %step ]
              %high = phi i64 [ %count, %search ], [ %next_high, %step ]
              %active = icmp slt i64 %low, %high
              br i1 %active, label %probe, label %choose

            probe:
              %span = sub i64 %high, %low
              %half = sdiv i64 %span, 2
              %mid = add i64 %low, %half
              %mid_result = call %smalllang.file_int_result @smalllang_platform_read_i64_at(i64 %mid)
              %mid_value = extractvalue %smalllang.file_int_result %mid_result, 0
              %mid_ok = extractvalue %smalllang.file_int_result %mid_result, 1
              %mid_is_ok = icmp ne i32 %mid_ok, 0
              br i1 %mid_is_ok, label %compare_mid, label %fail

            compare_mid:
              %less = icmp slt i64 %mid_value, %target
              br i1 %less, label %move_low, label %move_high

            move_low:
              %low_plus = add i64 %mid, 1
              br label %step

            move_high:
              br label %step

            step:
              %next_low = phi i64 [ %low_plus, %move_low ], [ %low, %move_high ]
              %next_high = phi i64 [ %high, %move_low ], [ %mid, %move_high ]
              br label %loop

            choose:
              %at_start = icmp eq i64 %low, 0
              br i1 %at_start, label %read_low, label %check_end

            check_end:
              %at_end = icmp eq i64 %low, %count
              br i1 %at_end, label %read_prev_only, label %read_pair

            read_low:
              %first_result = call %smalllang.file_int_result @smalllang_platform_read_i64_at(i64 0)
              ret %smalllang.file_int_result %first_result

            read_prev_only:
              %last_index = sub i64 %count, 1
              %last_result = call %smalllang.file_int_result @smalllang_platform_read_i64_at(i64 %last_index)
              ret %smalllang.file_int_result %last_result

            read_pair:
              %prev_index = sub i64 %low, 1
              %prev_result = call %smalllang.file_int_result @smalllang_platform_read_i64_at(i64 %prev_index)
              %next_result = call %smalllang.file_int_result @smalllang_platform_read_i64_at(i64 %low)
              %prev_ok = extractvalue %smalllang.file_int_result %prev_result, 1
              %next_ok = extractvalue %smalllang.file_int_result %next_result, 1
              %prev_is_ok = icmp ne i32 %prev_ok, 0
              %next_is_ok = icmp ne i32 %next_ok, 0
              %both_ok = and i1 %prev_is_ok, %next_is_ok
              br i1 %both_ok, label %compare_pair, label %fail

            compare_pair:
              %prev_value = extractvalue %smalllang.file_int_result %prev_result, 0
              %next_value = extractvalue %smalllang.file_int_result %next_result, 0
              %prev_diff = sub i64 %target, %prev_value
              %next_diff = sub i64 %next_value, %target
              %prefer_prev = icmp sle i64 %prev_diff, %next_diff
              br i1 %prefer_prev, label %return_prev, label %return_next

            return_prev:
              ret %smalllang.file_int_result %prev_result

            return_next:
              ret %smalllang.file_int_result %next_result

            fail:
              %fail0 = insertvalue %smalllang.file_int_result poison, i64 0, 0
              %fail1 = insertvalue %smalllang.file_int_result %fail0, i32 0, 1
              ret %smalllang.file_int_result %fail1
            }

            """);
    }

    private void EmitMain()
    {
        _locals.Clear();
        _currentFunctions = program.Functions;
        _mainOk = "true";
        _currentBlockLabel = "entry";
        _functions.Append("define dso_local i32 @")
            .Append(platform.EntryPointName)
            .AppendLine("() local_unnamed_addr {");
        _functions.AppendLine("entry:");
        _functions.AppendLine("  %written = alloca i32, align 4");
        _functions.AppendLine("  %read = alloca i32, align 4");
        _functions.AppendLine("  %ok_state = alloca i1, align 1");
        _functions.AppendLine("  store i1 true, ptr %ok_state, align 1");
        platform.EmitEntryHandles(_functions);

        EmitStatements(program.MainStatements);

        var finalOk = NextTemp("final_ok");
        _functions.Append("  ")
            .Append(finalOk)
            .AppendLine(" = load i1, ptr %ok_state, align 1");
        _functions.Append("  ")
            .Append(NextTemp("exit"))
            .Append(" = select i1 ")
            .Append(finalOk)
            .AppendLine(", i32 0, i32 1");
        _functions.Append("  ret i32 ").AppendLine(CurrentTemp("exit"));
        _functions.AppendLine("}");
        _functions.AppendLine();
    }

    private void EmitStatements(IReadOnlyList<Statement> statements)
    {
        foreach (var statement in statements)
        {
            EmitStatement(statement);
        }
    }

    private void EmitStatement(Statement statement)
    {
        switch (statement)
        {
            case BindingStatement binding:
                _locals.Add(binding.Name, EmitExpression(binding.Value));
                break;
            case BlockFunctionCallStatement blockFunctionCall:
                EmitBlockFunctionCall(blockFunctionCall);
                break;
            case ExpressionStatement expressionStatement:
                _mainOk = EmitExpressionStatement(expressionStatement.Expression, _mainOk);
                break;
            default:
                throw new SmallLangException($"unsupported runtime statement {statement.GetType().Name}");
        }
    }

    private void EmitBlockFunctionCall(BlockFunctionCallStatement statement)
    {
        var target = string.Join('.', statement.Target);
        switch (target)
        {
            case "each":
                if (statement.Source is not RangeExpression range)
                {
                    throw new SmallLangException("each expects a range input");
                }

                EmitEachBlockFunctionCall(statement, range);
                return;
            case "repeat":
                EmitRepeatBlockFunctionCall(statement);
                return;
            default:
                if (TryResolveFunction(statement.Target, out var function)
                    && function.Kind == BoundFunctionKind.UserBlock)
                {
                    EmitUserBlockFunctionCall(statement, function);
                    return;
                }

                throw new SmallLangException($"unknown block function '{target}'");
        }
    }

    private void EmitEachBlockFunctionCall(BlockFunctionCallStatement statement, RangeExpression range)
    {
        var start = EmitIntExpression(range.Start);
        var end = EmitIntExpression(range.End);
        var bodyLabel = NextLabel("each_body");
        var continueLabel = NextLabel("each_continue");
        var endLabel = NextLabel("each_end");
        var entryLabel = _currentBlockLabel;
        var next = NextTemp("each_next");
        var initialDone = NextTemp("each_done");

        _functions.Append("  ")
            .Append(initialDone)
            .Append(" = icmp sgt i64 ")
            .Append(start.ValueName)
            .Append(", ")
            .AppendLine(end.ValueName);
        _functions.Append("  br i1 ")
            .Append(initialDone)
            .Append(", label %")
            .Append(endLabel)
            .Append(", label %")
            .Append(bodyLabel)
            .AppendLine();

        _functions.Append(bodyLabel).AppendLine(":");
        _currentBlockLabel = bodyLabel;
        var item = NextTemp(statement.ItemName);
        _functions.Append("  ")
            .Append(item)
            .Append(" = phi i64 [ ")
            .Append(start.ValueName)
            .Append(", %")
            .Append(entryLabel)
            .Append(" ], [ ")
            .Append(next)
            .Append(", %")
            .Append(continueLabel)
            .AppendLine(" ]");

        var outerLocals = CaptureLocals();
        _locals[statement.ItemName] = new RuntimeInt(item);
        EmitStatements(statement.Body);
        RestoreLocals(outerLocals);

        _functions.Append("  br label %").AppendLine(continueLabel);
        _functions.Append(continueLabel).AppendLine(":");
        _currentBlockLabel = continueLabel;
        _functions.Append("  ")
            .Append(next)
            .Append(" = add i64 ")
            .Append(item)
            .AppendLine(", 1");
        var done = NextTemp("each_done");
        _functions.Append("  ")
            .Append(done)
            .Append(" = icmp sgt i64 ")
            .Append(next)
            .Append(", ")
            .AppendLine(end.ValueName);
        _functions.Append("  br i1 ")
            .Append(done)
            .Append(", label %")
            .Append(endLabel)
            .Append(", label %")
            .Append(bodyLabel)
            .AppendLine();
        _functions.Append(endLabel).AppendLine(":");
        _currentBlockLabel = endLabel;
    }

    private void EmitUserBlockFunctionCall(BlockFunctionCallStatement statement, BoundFunction function)
    {
        if (function.InputType is null || function.BlockInputType is null)
        {
            throw new SmallLangException($"block function '{function.Name}' is not callable");
        }

        var argument = EmitExpression(statement.Source);
        EnsureRuntimeType(argument, function.InputType.Value, function.Name);

        var callerLocals = CaptureLocals();
        var callerFunctions = _currentFunctions;
        var previousInvocation = _currentBlockInvocation;
        var previousFunctions = _currentFunctions;
        var blockLocals = new Dictionary<string, RuntimeValue>(StringComparer.Ordinal)
        {
            [function.InputName ?? "it"] = argument
        };

        _currentBlockInvocation = new RuntimeBlockInvocation(
            statement.ItemName,
            statement.Body,
            callerLocals,
            callerFunctions);
        _currentFunctions = CreateFunctionScope(_currentFunctions, function.LocalFunctions);
        RestoreLocals(blockLocals);
        try
        {
            EmitStatements(function.BlockBody);
        }
        finally
        {
            _currentBlockInvocation = previousInvocation;
            _currentFunctions = previousFunctions;
            RestoreLocals(callerLocals);
        }
    }

    private void EmitRepeatBlockFunctionCall(BlockFunctionCallStatement statement)
    {
        var count = EmitIntExpression(statement.Source);
        var bodyLabel = NextLabel("repeat_body");
        var continueLabel = NextLabel("repeat_continue");
        var endLabel = NextLabel("repeat_end");
        var entryLabel = _currentBlockLabel;
        var next = NextTemp("repeat_next");
        var initialDone = NextTemp("repeat_done");

        _functions.Append("  ")
            .Append(initialDone)
            .Append(" = icmp sle i64 ")
            .Append(count.ValueName)
            .AppendLine(", 0");
        _functions.Append("  br i1 ")
            .Append(initialDone)
            .Append(", label %")
            .Append(endLabel)
            .Append(", label %")
            .Append(bodyLabel)
            .AppendLine();

        _functions.Append(bodyLabel).AppendLine(":");
        _currentBlockLabel = bodyLabel;
        var item = NextTemp(statement.ItemName);
        _functions.Append("  ")
            .Append(item)
            .Append(" = phi i64 [ 1, %")
            .Append(entryLabel)
            .Append(" ], [ ")
            .Append(next)
            .Append(", %")
            .Append(continueLabel)
            .AppendLine(" ]");

        var outerLocals = CaptureLocals();
        _locals[statement.ItemName] = new RuntimeInt(item);
        EmitStatements(statement.Body);
        RestoreLocals(outerLocals);

        _functions.Append("  br label %").AppendLine(continueLabel);
        _functions.Append(continueLabel).AppendLine(":");
        _currentBlockLabel = continueLabel;
        _functions.Append("  ")
            .Append(next)
            .Append(" = add i64 ")
            .Append(item)
            .AppendLine(", 1");
        var done = NextTemp("repeat_done");
        _functions.Append("  ")
            .Append(done)
            .Append(" = icmp sgt i64 ")
            .Append(next)
            .Append(", ")
            .AppendLine(count.ValueName);
        _functions.Append("  br i1 ")
            .Append(done)
            .Append(", label %")
            .Append(endLabel)
            .Append(", label %")
            .Append(bodyLabel)
            .AppendLine();
        _functions.Append(endLabel).AppendLine(":");
        _currentBlockLabel = endLabel;
    }

    private string EmitExpressionStatement(Expression expression, string ok)
    {
        if (expression is CallExpression call)
        {
            var value = EmitFunctionCall(call);
            if (value.Type != BoundType.Unit)
            {
                throw new SmallLangException("only function calls with side effects are valid expression statements");
            }

            return _mainOk;
        }

        if (expression is FlowExpression flow)
        {
            var result = EmitFlowExpression(flow, ok, allowBindingTarget: true);
            if (result.Binding is { } binding)
            {
                _locals.Add(binding.Name, binding.Value);
                return result.Ok;
            }

            if (result.Value is null)
            {
                return result.Ok;
            }

            if (result.Value is RuntimeUnit)
            {
                return result.Ok;
            }

            throw new SmallLangException("value-flow expression statements must end in print or bind their result");
        }

        if (expression is IfExpression or WhenExpression)
        {
            var value = EmitExpression(expression);
            if (value.Type != BoundType.Unit)
            {
                throw new SmallLangException("conditional expression statements must produce Unit");
            }

            return _mainOk;
        }

        throw new SmallLangException($"unsupported runtime expression statement {expression.GetType().Name}");
    }

    private string EmitPrintArgument(Expression expression, string ok)
    {
        if (expression is StringExpression str)
        {
            foreach (var segment in str.Segments)
            {
                ok = segment switch
                {
                    TextSegment text => EmitWriteText(text.Text, ok),
                    InterpolationSegment interpolation => EmitWriteInterpolation(interpolation, ok),
                    _ => throw new SmallLangException($"unsupported string segment {segment.GetType().Name}")
                };
            }

            return ok;
        }

        var value = EmitExpression(expression);
        return EmitWriteValue(value, ok);
    }

    private string EmitWriteInterpolation(InterpolationSegment interpolation, string ok)
    {
        if (interpolation.Path.Count != 1)
        {
            throw new SmallLangException("path interpolation is reserved until modules are specified");
        }

        if (!_locals.TryGetValue(interpolation.Path[0], out var value))
        {
            throw new SmallLangException($"unknown runtime binding '{interpolation.Path[0]}'");
        }

        return EmitWriteValue(value, ok);
    }

    private string EmitWriteValue(RuntimeValue value, string ok)
    {
        return value switch
        {
            RuntimeText text => EmitWriteTextValue(text, ok),
            RuntimeInt integer => EmitWriteIntegerValue(integer, ok),
            _ => throw new SmallLangException($"unsupported runtime value {value.GetType().Name}")
        };
    }

    private string EmitWriteText(string text, string ok)
    {
        if (text.Length == 0)
        {
            return ok;
        }

        var global = AddGlobalString(text);
        return EmitWriteTextValue(new RuntimeText(global.Name, global.Length.ToString(CultureInfo.InvariantCulture)), ok);
    }

    private string EmitWriteTextValue(RuntimeText text, string ok)
    {
        var write = NextTemp("write");
        _functions.Append("  ")
            .Append(write)
            .Append(" = call i32 @smalllang_write(ptr %stdout, ptr ")
            .Append(text.PointerName)
            .Append(", i64 ")
            .Append(text.LengthName)
            .AppendLine(", ptr %written)");
        return CombineWriteOk(write, ok);
    }

    private string EmitWriteIntegerValue(RuntimeInt value, string ok)
    {
        var write = NextTemp("write");
        _functions.Append("  ")
            .Append(write)
            .Append(" = call i32 @smalllang_write_u64(ptr %stdout, i64 ")
            .Append(value.ValueName)
            .AppendLine(", ptr %written)");
        return CombineWriteOk(write, ok);
    }

    private string CombineWriteOk(string writeResult, string ok)
    {
        var isOk = NextTemp("is_ok");
        _functions.Append("  ")
            .Append(isOk)
            .Append(" = icmp ne i32 ")
            .Append(writeResult)
            .AppendLine(", 0");

        _ = ok;
        var previous = NextTemp("previous_ok");
        _functions.Append("  ")
            .Append(previous)
            .AppendLine(" = load i1, ptr %ok_state, align 1");
        var combined = NextTemp("ok");
        _functions.Append("  ")
            .Append(combined)
            .Append(" = and i1 ")
            .Append(previous)
            .Append(", ")
            .AppendLine(isOk);
        _functions.Append("  store i1 ")
            .Append(combined)
            .AppendLine(", ptr %ok_state, align 1");
        return combined;
    }

    private RuntimeValue EmitExpression(Expression expression)
    {
        return expression switch
        {
            StringExpression str => EmitTextLiteral(str),
            NumberExpression number => new RuntimeInt(ParseNumber(number).ToString(CultureInfo.InvariantCulture)),
            BoolExpression boolean => new RuntimeBool(boolean.Value ? "true" : "false"),
            NameExpression name => ResolveLocal(name.Name),
            AddExpression add => EmitAddExpression(add),
            SubtractExpression subtract => EmitSubtractExpression(subtract),
            MultiplyExpression multiply => EmitMultiplyExpression(multiply),
            DivideExpression divide => EmitDivideExpression(divide),
            ModuloExpression modulo => EmitModuloExpression(modulo),
            NegateExpression negate => EmitNegateExpression(negate),
            CompareExpression compare => EmitCompareExpression(compare),
            AndExpression and => EmitAndExpression(and),
            OrExpression or => EmitOrExpression(or),
            NotExpression not => EmitNotExpression(not),
            IfExpression conditional => EmitIfExpression(conditional),
            WhenExpression whenExpression => EmitWhenExpression(whenExpression),
            SubjectCompareExpression => throw new SmallLangException("subject comparison is only valid inside value-flow when"),
            SubjectRangeExpression => throw new SmallLangException("subject range is only valid inside value-flow when"),
            FoldExpression fold => EmitFoldExpression(fold),
            RangeExpression => throw new SmallLangException("range values are only valid as block-function input"),
            CallExpression call => EmitFunctionCall(call),
            FlowExpression flow => EmitFlowExpressionValue(flow),
            _ => throw new SmallLangException($"unsupported runtime expression {expression.GetType().Name}")
        };
    }

    private RuntimeText EmitTextLiteral(StringExpression expression)
    {
        var text = GetPlainText(expression, expression.Line, expression.Column);
        var global = AddGlobalString(text);
        return new RuntimeText(global.Name, global.Length.ToString(CultureInfo.InvariantCulture));
    }

    private RuntimeInt EmitIntExpression(Expression expression)
    {
        var value = EmitExpression(expression);
        return value as RuntimeInt
            ?? throw new SmallLangException("expected runtime integer expression");
    }

    private RuntimeBool EmitBoolExpression(Expression expression)
    {
        var value = EmitExpression(expression);
        return value as RuntimeBool
            ?? throw new SmallLangException("expected runtime boolean expression");
    }

    private RuntimeInt EmitAddExpression(AddExpression expression)
    {
        var left = EmitIntExpression(expression.Left);
        var right = EmitIntExpression(expression.Right);
        var result = NextTemp("add");
        _functions.Append("  ")
            .Append(result)
            .Append(" = add nsw i64 ")
            .Append(left.ValueName)
            .Append(", ")
            .AppendLine(right.ValueName);
        return new RuntimeInt(result);
    }

    private RuntimeInt EmitMultiplyExpression(MultiplyExpression expression)
    {
        var left = EmitIntExpression(expression.Left);
        var right = EmitIntExpression(expression.Right);
        var result = NextTemp("mul");
        _functions.Append("  ")
            .Append(result)
            .Append(" = mul nsw i64 ")
            .Append(left.ValueName)
            .Append(", ")
            .AppendLine(right.ValueName);
        return new RuntimeInt(result);
    }

    private RuntimeInt EmitSubtractExpression(SubtractExpression expression)
    {
        var left = EmitIntExpression(expression.Left);
        var right = EmitIntExpression(expression.Right);
        var result = NextTemp("sub");
        _functions.Append("  ")
            .Append(result)
            .Append(" = sub nsw i64 ")
            .Append(left.ValueName)
            .Append(", ")
            .AppendLine(right.ValueName);
        return new RuntimeInt(result);
    }

    private RuntimeInt EmitDivideExpression(DivideExpression expression)
    {
        var left = EmitIntExpression(expression.Left);
        var right = EmitIntExpression(expression.Right);
        var result = NextTemp("div");
        _functions.Append("  ")
            .Append(result)
            .Append(" = sdiv i64 ")
            .Append(left.ValueName)
            .Append(", ")
            .AppendLine(right.ValueName);
        return new RuntimeInt(result);
    }

    private RuntimeInt EmitModuloExpression(ModuloExpression expression)
    {
        var left = EmitIntExpression(expression.Left);
        var right = EmitIntExpression(expression.Right);
        var result = NextTemp("mod");
        _functions.Append("  ")
            .Append(result)
            .Append(" = srem i64 ")
            .Append(left.ValueName)
            .Append(", ")
            .AppendLine(right.ValueName);
        return new RuntimeInt(result);
    }

    private RuntimeInt EmitNegateExpression(NegateExpression expression)
    {
        var value = EmitIntExpression(expression.Value);
        var result = NextTemp("neg");
        _functions.Append("  ")
            .Append(result)
            .Append(" = sub nsw i64 0, ")
            .AppendLine(value.ValueName);
        return new RuntimeInt(result);
    }

    private RuntimeBool EmitCompareExpression(CompareExpression expression)
    {
        var left = EmitIntExpression(expression.Left);
        var right = EmitIntExpression(expression.Right);
        return EmitIntegerComparison(left, expression.Operator, right);
    }

    private RuntimeBool EmitIntegerComparison(RuntimeInt left, ComparisonOperator comparisonOperator, RuntimeInt right)
    {
        var result = NextTemp("cmp");
        _functions.Append("  ")
            .Append(result)
            .Append(" = icmp ")
            .Append(comparisonOperator switch
            {
                ComparisonOperator.Equal => "eq",
                ComparisonOperator.NotEqual => "ne",
                ComparisonOperator.Less => "slt",
                ComparisonOperator.LessOrEqual => "sle",
                ComparisonOperator.Greater => "sgt",
                ComparisonOperator.GreaterOrEqual => "sge",
                _ => throw new SmallLangException($"unsupported comparison operator '{comparisonOperator}'")
            })
            .Append(" i64 ")
            .Append(left.ValueName)
            .Append(", ")
            .AppendLine(right.ValueName);
        return new RuntimeBool(result);
    }

    private RuntimeBool EmitAndExpression(AndExpression expression)
    {
        var left = EmitBoolExpression(expression.Left);
        var rhsLabel = NextLabel("and_rhs");
        var endLabel = NextLabel("and_end");
        var entryLabel = _currentBlockLabel;

        _functions.Append("  br i1 ")
            .Append(left.ValueName)
            .Append(", label %")
            .Append(rhsLabel)
            .Append(", label %")
            .Append(endLabel)
            .AppendLine();

        _functions.Append(rhsLabel).AppendLine(":");
        _currentBlockLabel = rhsLabel;
        var right = EmitBoolExpression(expression.Right);
        var rightLabel = _currentBlockLabel;
        _functions.Append("  br label %").AppendLine(endLabel);

        _functions.Append(endLabel).AppendLine(":");
        _currentBlockLabel = endLabel;
        var result = NextTemp("and");
        _functions.Append("  ")
            .Append(result)
            .Append(" = phi i1 [ false, %")
            .Append(entryLabel)
            .Append(" ], [ ")
            .Append(right.ValueName)
            .Append(", %")
            .Append(rightLabel)
            .AppendLine(" ]");
        return new RuntimeBool(result);
    }

    private RuntimeBool EmitOrExpression(OrExpression expression)
    {
        var left = EmitBoolExpression(expression.Left);
        var rhsLabel = NextLabel("or_rhs");
        var endLabel = NextLabel("or_end");
        var entryLabel = _currentBlockLabel;

        _functions.Append("  br i1 ")
            .Append(left.ValueName)
            .Append(", label %")
            .Append(endLabel)
            .Append(", label %")
            .Append(rhsLabel)
            .AppendLine();

        _functions.Append(rhsLabel).AppendLine(":");
        _currentBlockLabel = rhsLabel;
        var right = EmitBoolExpression(expression.Right);
        var rightLabel = _currentBlockLabel;
        _functions.Append("  br label %").AppendLine(endLabel);

        _functions.Append(endLabel).AppendLine(":");
        _currentBlockLabel = endLabel;
        var result = NextTemp("or");
        _functions.Append("  ")
            .Append(result)
            .Append(" = phi i1 [ true, %")
            .Append(entryLabel)
            .Append(" ], [ ")
            .Append(right.ValueName)
            .Append(", %")
            .Append(rightLabel)
            .AppendLine(" ]");
        return new RuntimeBool(result);
    }

    private RuntimeBool EmitNotExpression(NotExpression expression)
    {
        var value = EmitBoolExpression(expression.Value);
        var result = NextTemp("not");
        _functions.Append("  ")
            .Append(result)
            .Append(" = xor i1 ")
            .Append(value.ValueName)
            .AppendLine(", true");
        return new RuntimeBool(result);
    }

    private RuntimeValue EmitIfExpression(IfExpression expression)
    {
        var condition = EmitBoolExpression(expression.Condition);
        var thenLabel = NextLabel("if_then");
        var elseLabel = expression.Else is null ? null : NextLabel("if_else");
        var endLabel = NextLabel("if_end");

        _functions.Append("  br i1 ")
            .Append(condition.ValueName)
            .Append(", label %")
            .Append(thenLabel)
            .Append(", label %")
            .Append(elseLabel ?? endLabel)
            .AppendLine();

        _functions.Append(thenLabel).AppendLine(":");
        _currentBlockLabel = thenLabel;
        var thenResult = EmitScopedBlockBody(expression.Then);
        var thenEndLabel = _currentBlockLabel;
        _functions.Append("  br label %").AppendLine(endLabel);

        BlockResult? elseResult = null;
        if (expression.Else is not null)
        {
            var activeElseLabel = elseLabel!;
            _functions.Append(activeElseLabel).AppendLine(":");
            _currentBlockLabel = activeElseLabel;
            elseResult = EmitScopedBlockBody(expression.Else);
            _functions.Append("  br label %").AppendLine(endLabel);
        }

        _functions.Append(endLabel).AppendLine(":");
        _currentBlockLabel = endLabel;

        if (expression.Else is null || thenResult.Value is null || elseResult?.Value is null)
        {
            return RuntimeUnit.Instance;
        }

        return EmitPhiValue("if", thenResult.Value, thenEndLabel, elseResult.Value, elseResult.EndLabel);
    }

    private RuntimeValue EmitWhenExpression(WhenExpression expression)
    {
        var endLabel = NextLabel("when_end");
        var valueResults = new List<(RuntimeValue Value, string Label)>();
        var hasSubjectConditions = expression.Arms.Any(static arm => IsSubjectWhenCondition(arm.Condition));
        var subject = expression.Subject is not null
            ? EmitIntExpression(expression.Subject)
            : hasSubjectConditions
                ? ResolveLocal("it") as RuntimeInt
                    ?? throw new SmallLangException("subject-style when without an explicit subject requires runtime integer binding 'it'")
                : null;
        var nextConditionLabel = _currentBlockLabel;

        foreach (var arm in expression.Arms)
        {
            _currentBlockLabel = nextConditionLabel;
            var armLabel = NextLabel("when_arm");
            var nextLabel = NextLabel("when_next");
            var condition = subject is null
                ? EmitBoolExpression(arm.Condition)
                : EmitSubjectWhenCondition(subject, arm.Condition);
            _functions.Append("  br i1 ")
                .Append(condition.ValueName)
                .Append(", label %")
                .Append(armLabel)
                .Append(", label %")
                .Append(nextLabel)
                .AppendLine();

            _functions.Append(armLabel).AppendLine(":");
            _currentBlockLabel = armLabel;
            var armResult = EmitScopedBlockBody(arm.Body);
            if (armResult.Value is not null)
            {
                valueResults.Add((armResult.Value, armResult.EndLabel));
            }

            _functions.Append("  br label %").AppendLine(endLabel);
            _functions.Append(nextLabel).AppendLine(":");
            nextConditionLabel = nextLabel;
        }

        _currentBlockLabel = nextConditionLabel;
        var elseResult = EmitScopedBlockBody(expression.Else);
        if (elseResult.Value is not null)
        {
            valueResults.Add((elseResult.Value, elseResult.EndLabel));
        }

        _functions.Append("  br label %").AppendLine(endLabel);
        _functions.Append(endLabel).AppendLine(":");
        _currentBlockLabel = endLabel;

        if (valueResults.Count == 0)
        {
            return RuntimeUnit.Instance;
        }

        return EmitPhiValue("when", valueResults);
    }

    private static bool IsSubjectWhenCondition(Expression condition)
    {
        return condition is SubjectCompareExpression or SubjectRangeExpression;
    }

    private RuntimeBool EmitSubjectWhenCondition(RuntimeInt subject, Expression condition)
    {
        if (condition is SubjectCompareExpression compare)
        {
            return EmitIntegerComparison(subject, compare.Operator, EmitIntExpression(compare.Right));
        }

        if (condition is not SubjectRangeExpression range)
        {
            throw new SmallLangException("value-flow when arm must start with a comparison operator or range");
        }

        var lower = EmitIntegerComparison(subject, ComparisonOperator.GreaterOrEqual, EmitIntExpression(range.Start));
        var upper = EmitIntegerComparison(subject, ComparisonOperator.LessOrEqual, EmitIntExpression(range.End));
        var result = NextTemp("range");
        _functions.Append("  ")
            .Append(result)
            .Append(" = and i1 ")
            .Append(lower.ValueName)
            .Append(", ")
            .AppendLine(upper.ValueName);
        return new RuntimeBool(result);
    }

    private RuntimeInt EmitFoldExpression(FoldExpression expression)
    {
        var start = EmitIntExpression(expression.Source.Start);
        var end = EmitIntExpression(expression.Source.End);
        var initial = EmitIntExpression(expression.Initial);
        var bodyLabel = NextLabel("fold_body");
        var continueLabel = NextLabel("fold_continue");
        var endLabel = NextLabel("fold_end");
        var entryLabel = _currentBlockLabel;
        var nextItem = NextTemp("fold_next");
        var initialDone = NextTemp("fold_done");

        _functions.Append("  ")
            .Append(initialDone)
            .Append(" = icmp sgt i64 ")
            .Append(start.ValueName)
            .Append(", ")
            .AppendLine(end.ValueName);
        _functions.Append("  br i1 ")
            .Append(initialDone)
            .Append(", label %")
            .Append(endLabel)
            .Append(", label %")
            .Append(bodyLabel)
            .AppendLine();

        _functions.Append(bodyLabel).AppendLine(":");
        _currentBlockLabel = bodyLabel;
        var item = NextTemp(expression.ItemName);
        _functions.Append("  ")
            .Append(item)
            .Append(" = phi i64 [ ")
            .Append(start.ValueName)
            .Append(", %")
            .Append(entryLabel)
            .Append(" ], [ ")
            .Append(nextItem)
            .Append(", %")
            .Append(continueLabel)
            .AppendLine(" ]");

        var nextAccumulator = NextTemp("fold_acc_next");
        var accumulator = NextTemp(expression.AccumulatorName);
        _functions.Append("  ")
            .Append(accumulator)
            .Append(" = phi i64 [ ")
            .Append(initial.ValueName)
            .Append(", %")
            .Append(entryLabel)
            .Append(" ], [ ")
            .Append(nextAccumulator)
            .Append(", %")
            .Append(continueLabel)
            .AppendLine(" ]");

        var outerLocals = CaptureLocals();
        _locals[expression.AccumulatorName] = new RuntimeInt(accumulator);
        _locals[expression.ItemName] = new RuntimeInt(item);
        var bodyResult = EmitScopedBlockBody(expression.Body);
        RestoreLocals(outerLocals);
        if (bodyResult.Value is not RuntimeInt bodyValue)
        {
            throw new SmallLangException("fold body must return an integer accumulator value");
        }

        _functions.Append("  ")
            .Append(nextAccumulator)
            .Append(" = add i64 ")
            .Append(bodyValue.ValueName)
            .AppendLine(", 0");
        _functions.Append("  br label %").AppendLine(continueLabel);

        _functions.Append(continueLabel).AppendLine(":");
        _currentBlockLabel = continueLabel;
        _functions.Append("  ")
            .Append(nextItem)
            .Append(" = add i64 ")
            .Append(item)
            .AppendLine(", 1");
        var done = NextTemp("fold_done");
        _functions.Append("  ")
            .Append(done)
            .Append(" = icmp sgt i64 ")
            .Append(nextItem)
            .Append(", ")
            .AppendLine(end.ValueName);
        _functions.Append("  br i1 ")
            .Append(done)
            .Append(", label %")
            .Append(endLabel)
            .Append(", label %")
            .Append(bodyLabel)
            .AppendLine();

        _functions.Append(endLabel).AppendLine(":");
        _currentBlockLabel = endLabel;
        var result = NextTemp("fold");
        _functions.Append("  ")
            .Append(result)
            .Append(" = phi i64 [ ")
            .Append(initial.ValueName)
            .Append(", %")
            .Append(entryLabel)
            .Append(" ], [ ")
            .Append(nextAccumulator)
            .Append(", %")
            .Append(continueLabel)
            .AppendLine(" ]");
        return new RuntimeInt(result);
    }

    private BlockResult EmitScopedBlockBody(BlockBody body)
    {
        var outerLocals = CaptureLocals();
        try
        {
            EmitStatements(body.Statements);
            var value = body.Value is null ? null : EmitExpression(body.Value);
            return new BlockResult(value, _currentBlockLabel);
        }
        finally
        {
            RestoreLocals(outerLocals);
        }
    }

    private RuntimeValue EmitPhiValue(
        string prefix,
        RuntimeValue left,
        string leftLabel,
        RuntimeValue right,
        string rightLabel)
    {
        return EmitPhiValue(prefix, [(left, leftLabel), (right, rightLabel)]);
    }

    private RuntimeValue EmitPhiValue(string prefix, IReadOnlyList<(RuntimeValue Value, string Label)> incoming)
    {
        return incoming[0].Value switch
        {
            RuntimeInt => new RuntimeInt(EmitScalarPhi(prefix, "i64", incoming)),
            RuntimeBool => new RuntimeBool(EmitScalarPhi(prefix, "i1", incoming)),
            RuntimeText => EmitTextPhi(prefix, incoming),
            RuntimeUnit => RuntimeUnit.Instance,
            _ => throw new SmallLangException($"unsupported phi value {incoming[0].Value.GetType().Name}")
        };
    }

    private string EmitScalarPhi(string prefix, string typeName, IReadOnlyList<(RuntimeValue Value, string Label)> incoming)
    {
        var result = NextTemp(prefix);
        _functions.Append("  ")
            .Append(result)
            .Append(" = phi ")
            .Append(typeName)
            .Append(' ');
        AppendPhiIncoming(incoming, static value => value switch
        {
            RuntimeInt integer => integer.ValueName,
            RuntimeBool boolean => boolean.ValueName,
            _ => throw new SmallLangException($"unsupported scalar phi value {value.GetType().Name}")
        });
        _functions.AppendLine();
        return result;
    }

    private RuntimeText EmitTextPhi(string prefix, IReadOnlyList<(RuntimeValue Value, string Label)> incoming)
    {
        var pointer = NextTemp(prefix + "_ptr");
        _functions.Append("  ")
            .Append(pointer)
            .Append(" = phi ptr ");
        AppendPhiIncoming(incoming, static value => ((RuntimeText)value).PointerName);
        _functions.AppendLine();

        var length = NextTemp(prefix + "_len");
        _functions.Append("  ")
            .Append(length)
            .Append(" = phi i64 ");
        AppendPhiIncoming(incoming, static value => ((RuntimeText)value).LengthName);
        _functions.AppendLine();

        return new RuntimeText(pointer, length);
    }

    private void AppendPhiIncoming(
        IReadOnlyList<(RuntimeValue Value, string Label)> incoming,
        Func<RuntimeValue, string> getValueName)
    {
        for (var i = 0; i < incoming.Count; i++)
        {
            if (i > 0)
            {
                _functions.Append(", ");
            }

            _functions.Append("[ ")
                .Append(getValueName(incoming[i].Value))
                .Append(", %")
                .Append(incoming[i].Label)
                .Append(" ]");
        }
    }

    private RuntimeValue EmitFlowExpressionValue(FlowExpression expression)
    {
        var result = EmitFlowExpression(expression, ok: "true", allowBindingTarget: false);
        return result.Value
            ?? RuntimeUnit.Instance;
    }

    private RuntimeFlowResult EmitFlowExpression(FlowExpression expression, string ok, bool allowBindingTarget)
    {
        if (expression.Targets.Count == 1
            && expression.Targets[0].UsesCallSyntax
            && TryResolveFunction(expression.Targets[0].Path, out var directFunction)
            && TryGetRuntimePrinterKind(directFunction, out var directPrinterKind))
        {
            ok = EmitPrintFlowSource(expression.Source, ok);
            if (directPrinterKind == BoundFunctionKind.RuntimePrintLine)
            {
                ok = EmitWriteText("\n", ok);
            }

            return new RuntimeFlowResult(
                Value: null,
                Binding: null,
                Ok: ok);
        }

        var current = EmitFlowSource(expression.Source);
        for (var i = 0; i < expression.Targets.Count; i++)
        {
            var target = expression.Targets[i];
            var isLast = i == expression.Targets.Count - 1;
            var path = string.Join('.', target.Path);

            if (path == "yield")
            {
                if (_currentBlockInvocation is null)
                {
                    throw new SmallLangException("yield() is only valid inside a block function");
                }

                if (!target.UsesCallSyntax)
                {
                    throw new SmallLangException("yield must use empty call syntax 'yield()'");
                }

                if (!isLast)
                {
                    throw new SmallLangException("yield() must be the final value-flow target");
                }

                EmitYield(current, _currentBlockInvocation);
                return new RuntimeFlowResult(
                    Value: null,
                    Binding: null,
                    Ok: ok);
            }

            if (TryResolveFunction(target.Path, out var function))
            {
                if (!target.UsesCallSyntax)
                {
                    throw new SmallLangException($"function value-flow target '{path}' must use empty call syntax '{path}()' unless it is followed by a block argument");
                }

                switch (function.Kind)
                {
                    case BoundFunctionKind.RuntimePrint:
                    case BoundFunctionKind.RuntimePrintLine:
                        if (!isLast)
                        {
                            throw new SmallLangException($"{path} must be the final value-flow target");
                        }

                        ok = EmitWriteValue(current, ok);
                        if (function.Kind == BoundFunctionKind.RuntimePrintLine)
                        {
                            ok = EmitWriteText("\n", ok);
                        }

                        return new RuntimeFlowResult(
                            Value: null,
                            Binding: null,
                            Ok: ok);
                    case BoundFunctionKind.RuntimeReadInt:
                        EnsureRuntimeType(current, BoundType.Text, path);
                        current = EmitReadIntPrompt(current);
                        ok = _mainOk;
                        continue;
                    case BoundFunctionKind.RuntimeSeedRandom:
                    case BoundFunctionKind.RuntimeOpenIntWriter:
                    case BoundFunctionKind.RuntimeWriteInt:
                    case BoundFunctionKind.RuntimeOpenIntReader:
                        if (!isLast)
                        {
                            throw new SmallLangException($"{path} must be the final value-flow target");
                        }

                        EmitRuntimeUnitIntrinsic(function, current, path);
                        return new RuntimeFlowResult(
                            Value: null,
                            Binding: null,
                            Ok: _mainOk);
                    case BoundFunctionKind.RuntimeRandomBelow:
                    case BoundFunctionKind.RuntimeClosestInt:
                        current = EmitRuntimeIntIntrinsic(function, current, path);
                        ok = _mainOk;
                        continue;
                    case BoundFunctionKind.RuntimeCloseIntWriter:
                    case BoundFunctionKind.RuntimeCloseIntReader:
                        throw new SmallLangException($"{path} does not accept a flowed input");
                    case BoundFunctionKind.User:
                        current = EmitFlowFunctionCall(function, current);
                        continue;
                    default:
                        throw new SmallLangException($"unsupported runtime function kind '{function.Kind}'");
                }
            }

            if (allowBindingTarget && isLast && !target.UsesCallSyntax && target.Path.Count == 1)
            {
                return new RuntimeFlowResult(
                    Value: null,
                    Binding: new RuntimeFlowBinding(target.Path[0], current),
                    Ok: ok);
            }

            var targetKind = target.UsesCallSyntax ? "function" : "value-flow target";
            throw new SmallLangException($"unknown runtime {targetKind} '{path}'");
        }

        return new RuntimeFlowResult(
            Value: current,
            Binding: null,
            Ok: ok);
    }

    private RuntimeValue EmitFlowSource(Expression source)
    {
        return EmitExpression(source);
    }

    private string EmitPrintFlowSource(Expression expression, string ok)
    {
        if (expression is StringExpression str)
        {
            return EmitPrintArgument(str, ok);
        }

        var value = EmitFlowSource(expression);
        return EmitWriteValue(value, ok);
    }

    private RuntimeInt EmitReadIntPrompt(RuntimeValue prompt)
    {
        EnsureRuntimeType(prompt, BoundType.Text, "sys.io.readInt");
        _mainOk = EmitWriteValue(prompt, _mainOk);
        return EmitReadIntAfterPrompt();
    }

    private RuntimeInt EmitReadIntPromptExpression(Expression prompt)
    {
        _mainOk = EmitPrintArgument(prompt, _mainOk);
        return EmitReadIntAfterPrompt();
    }

    private RuntimeInt EmitReadIntAfterPrompt()
    {
        var result = NextTemp("read_int");
        _functions.Append("  ")
            .Append(result)
            .AppendLine(" = call %smalllang.read_int_result @smalllang_read_i64(ptr %stdin, ptr %read)");

        var value = NextTemp("read_value");
        _functions.Append("  ")
            .Append(value)
            .Append(" = extractvalue %smalllang.read_int_result ")
            .Append(result)
            .AppendLine(", 0");

        var ok = NextTemp("read_ok");
        _functions.Append("  ")
            .Append(ok)
            .Append(" = extractvalue %smalllang.read_int_result ")
            .Append(result)
            .AppendLine(", 1");

        _mainOk = CombineWriteOk(ok, _mainOk);
        EmitReturnIfReadFailed(ok);
        return new RuntimeInt(value);
    }

    private void EmitReturnIfReadFailed(string readOk)
    {
        var isOk = NextTemp("read_is_ok");
        var failLabel = NextLabel("read_fail");
        var continueLabel = NextLabel("read_continue");

        _functions.Append("  ")
            .Append(isOk)
            .Append(" = icmp ne i32 ")
            .Append(readOk)
            .AppendLine(", 0");
        _functions.Append("  br i1 ")
            .Append(isOk)
            .Append(", label %")
            .Append(continueLabel)
            .Append(", label %")
            .Append(failLabel)
            .AppendLine();
        _functions.Append(failLabel).AppendLine(":");
        _functions.AppendLine("  ret i32 1");
        _functions.Append(continueLabel).AppendLine(":");
        _currentBlockLabel = continueLabel;
    }

    private RuntimeUnit EmitRuntimeUnitIntrinsic(BoundFunction function, RuntimeValue? argument, string path)
    {
        return EmitRuntimeUnitIntrinsic(function.Kind, argument, path);
    }

    private RuntimeUnit EmitRuntimeUnitIntrinsic(BoundFunctionKind kind, RuntimeValue? argument, string path)
    {
        var ok = kind switch
        {
            BoundFunctionKind.RuntimeSeedRandom => EmitRuntimeIntStatusCall(
                "smalllang_seed_random",
                argument,
                path),
            BoundFunctionKind.RuntimeOpenIntWriter => EmitRuntimeTextStatusCall(
                "smalllang_open_write_i64_file",
                argument,
                path),
            BoundFunctionKind.RuntimeWriteInt => EmitRuntimeIntStatusCall(
                "smalllang_write_i64_file",
                argument,
                path),
            BoundFunctionKind.RuntimeCloseIntWriter => EmitRuntimeNoArgumentStatusCall(
                "smalllang_close_write_i64_file",
                argument,
                path),
            BoundFunctionKind.RuntimeOpenIntReader => EmitRuntimeTextStatusCall(
                "smalllang_platform_open_read_file",
                argument,
                path),
            BoundFunctionKind.RuntimeCloseIntReader => EmitRuntimeNoArgumentStatusCall(
                "smalllang_platform_close_read_file",
                argument,
                path),
            _ => throw new SmallLangException($"unsupported runtime unit intrinsic '{kind}'")
        };

        _mainOk = CombineWriteOk(ok, _mainOk);
        EmitReturnIfReadFailed(ok);
        return RuntimeUnit.Instance;
    }

    private string EmitRuntimeNoArgumentStatusCall(string functionName, RuntimeValue? argument, string path)
    {
        if (argument is not null)
        {
            throw new SmallLangException($"{path} does not accept an argument");
        }

        var ok = NextTemp("runtime_ok");
        _functions.Append("  ")
            .Append(ok)
            .Append(" = call i32 @")
            .Append(functionName)
            .AppendLine("()");
        return ok;
    }

    private string EmitRuntimeTextStatusCall(string functionName, RuntimeValue? argument, string path)
    {
        if (argument is not RuntimeText text)
        {
            throw new SmallLangException($"{path} expects Text");
        }

        var ok = NextTemp("runtime_ok");
        _functions.Append("  ")
            .Append(ok)
            .Append(" = call i32 @")
            .Append(functionName)
            .Append("(ptr ")
            .Append(text.PointerName)
            .Append(", i64 ")
            .Append(text.LengthName)
            .AppendLine(")");
        return ok;
    }

    private string EmitRuntimeIntStatusCall(string functionName, RuntimeValue? argument, string path)
    {
        if (argument is not RuntimeInt integer)
        {
            throw new SmallLangException($"{path} expects Int");
        }

        var ok = NextTemp("runtime_ok");
        _functions.Append("  ")
            .Append(ok)
            .Append(" = call i32 @")
            .Append(functionName)
            .Append("(i64 ")
            .Append(integer.ValueName)
            .AppendLine(")");
        return ok;
    }

    private RuntimeInt EmitRuntimeIntIntrinsic(BoundFunction function, RuntimeValue argument, string path)
    {
        return EmitRuntimeIntIntrinsic(function.Kind, argument, path);
    }

    private RuntimeInt EmitRuntimeIntIntrinsic(BoundFunctionKind kind, RuntimeValue argument, string path)
    {
        if (argument is not RuntimeInt integer)
        {
            throw new SmallLangException($"{path} expects Int");
        }

        var helperName = kind switch
        {
            BoundFunctionKind.RuntimeRandomBelow => "smalllang_random_below",
            BoundFunctionKind.RuntimeClosestInt => "smalllang_closest_i64_file",
            _ => throw new SmallLangException($"unsupported runtime int intrinsic '{kind}'")
        };

        var result = NextTemp("runtime_int");
        _functions.Append("  ")
            .Append(result)
            .Append(" = call %smalllang.file_int_result @")
            .Append(helperName)
            .Append("(i64 ")
            .Append(integer.ValueName)
            .AppendLine(")");

        var value = NextTemp("runtime_value");
        _functions.Append("  ")
            .Append(value)
            .Append(" = extractvalue %smalllang.file_int_result ")
            .Append(result)
            .AppendLine(", 0");

        var ok = NextTemp("runtime_ok");
        _functions.Append("  ")
            .Append(ok)
            .Append(" = extractvalue %smalllang.file_int_result ")
            .Append(result)
            .AppendLine(", 1");

        _mainOk = CombineWriteOk(ok, _mainOk);
        EmitReturnIfReadFailed(ok);
        return new RuntimeInt(value);
    }

    private RuntimeValue EmitFunctionCall(CallExpression expression)
    {
        var path = string.Join('.', expression.Path);
        if (!TryResolveFunction(expression.Path, out var function))
        {
            throw new SmallLangException($"unknown runtime function '{path}'");
        }

        if (TryGetRuntimeWrapperKind(function, out var wrapperKind))
        {
            return EmitRuntimeWrapperCall(expression, wrapperKind, path);
        }

        if (function.Kind is BoundFunctionKind.RuntimePrint or BoundFunctionKind.RuntimePrintLine)
        {
            if (expression.Arguments.Count != 1)
            {
                throw new SmallLangException($"{path} expects exactly one argument");
            }

            _mainOk = EmitPrintArgument(expression.Arguments[0], _mainOk);
            if (function.Kind == BoundFunctionKind.RuntimePrintLine)
            {
                _mainOk = EmitWriteText("\n", _mainOk);
            }

            return RuntimeUnit.Instance;
        }

        if (function.Kind == BoundFunctionKind.RuntimeReadInt)
        {
            if (expression.Arguments.Count != 1)
            {
                throw new SmallLangException($"{path} expects exactly one Text prompt");
            }

            var prompt = EmitExpression(expression.Arguments[0]);
            EnsureRuntimeType(prompt, BoundType.Text, path);
            return EmitReadIntPrompt(prompt);
        }

        if (function.Kind is BoundFunctionKind.RuntimeSeedRandom
            or BoundFunctionKind.RuntimeOpenIntWriter
            or BoundFunctionKind.RuntimeWriteInt
            or BoundFunctionKind.RuntimeOpenIntReader)
        {
            if (expression.Arguments.Count != 1)
            {
                throw new SmallLangException($"{path} expects exactly one argument");
            }

            var runtimeArgument = EmitExpression(expression.Arguments[0]);
            EmitRuntimeUnitIntrinsic(function, runtimeArgument, path);
            return RuntimeUnit.Instance;
        }

        if (function.Kind is BoundFunctionKind.RuntimeRandomBelow
            or BoundFunctionKind.RuntimeClosestInt)
        {
            if (expression.Arguments.Count != 1)
            {
                throw new SmallLangException($"{path} expects exactly one argument");
            }

            var runtimeArgument = EmitExpression(expression.Arguments[0]);
            return EmitRuntimeIntIntrinsic(function, runtimeArgument, path);
        }

        if (function.Kind is BoundFunctionKind.RuntimeCloseIntWriter
            or BoundFunctionKind.RuntimeCloseIntReader)
        {
            if (expression.Arguments.Count != 0)
            {
                throw new SmallLangException($"{path} does not accept arguments");
            }

            EmitRuntimeUnitIntrinsic(function, argument: null, path);
            return RuntimeUnit.Instance;
        }

        if (function.Kind != BoundFunctionKind.User)
        {
            throw new SmallLangException($"unsupported runtime function kind '{function.Kind}'");
        }

        RuntimeValue? argument = null;
        if (function.InputType is null)
        {
            if (expression.Arguments.Count != 0)
            {
                throw new SmallLangException($"function '{path}' does not accept arguments");
            }
        }
        else
        {
            if (expression.Arguments.Count != 1)
            {
                throw new SmallLangException($"function '{path}' expects exactly one argument");
            }

            argument = EmitExpression(expression.Arguments[0]);
            EnsureRuntimeType(argument, function.InputType.Value, path);
        }

        return EmitFunctionCall(function, argument);
    }

    private RuntimeValue EmitRuntimeWrapperCall(
        CallExpression expression,
        BoundFunctionKind wrapperKind,
        string path)
    {
        if (expression.Arguments.Count != 1)
        {
            throw new SmallLangException($"{path} expects exactly one argument");
        }

        return wrapperKind switch
        {
            BoundFunctionKind.RuntimePrint => EmitRuntimePrintCall(expression.Arguments[0], appendNewLine: false),
            BoundFunctionKind.RuntimePrintLine => EmitRuntimePrintCall(expression.Arguments[0], appendNewLine: true),
            BoundFunctionKind.RuntimeReadInt => EmitReadIntPromptExpression(expression.Arguments[0]),
            BoundFunctionKind.RuntimeSeedRandom
                or BoundFunctionKind.RuntimeOpenIntWriter
                or BoundFunctionKind.RuntimeWriteInt
                or BoundFunctionKind.RuntimeOpenIntReader
                => EmitRuntimeUnitWrapperCall(expression.Arguments[0], wrapperKind, path),
            BoundFunctionKind.RuntimeRandomBelow
                or BoundFunctionKind.RuntimeClosestInt
                => EmitRuntimeIntWrapperCall(expression.Arguments[0], wrapperKind, path),
            _ => throw new SmallLangException($"unsupported runtime wrapper kind '{wrapperKind}'")
        };
    }

    private RuntimeUnit EmitRuntimeUnitWrapperCall(Expression argument, BoundFunctionKind kind, string path)
    {
        var value = EmitExpression(argument);
        EmitRuntimeUnitIntrinsic(kind, value, path);
        return RuntimeUnit.Instance;
    }

    private RuntimeInt EmitRuntimeIntWrapperCall(Expression argument, BoundFunctionKind kind, string path)
    {
        var value = EmitExpression(argument);
        return EmitRuntimeIntIntrinsic(kind, value, path);
    }

    private RuntimeUnit EmitRuntimePrintCall(Expression argument, bool appendNewLine)
    {
        _mainOk = EmitPrintArgument(argument, _mainOk);
        if (appendNewLine)
        {
            _mainOk = EmitWriteText("\n", _mainOk);
        }

        return RuntimeUnit.Instance;
    }

    private RuntimeValue EmitFlowFunctionCall(BoundFunction function, RuntimeValue argument)
    {
        if (function.InputType is null)
        {
            throw new SmallLangException($"function '{function.Name}' does not accept a flowed input");
        }

        EnsureRuntimeType(argument, function.InputType.Value, function.Name);
        return EmitFunctionCall(function, argument);
    }

    private RuntimeValue EmitInlineFunctionCall(BoundFunction function, RuntimeValue? argument)
    {
        if (function.Body is null)
        {
            throw new SmallLangException($"function '{function.Name}' has no body");
        }

        if (_inlineFunctionStack.Any(candidate => ReferenceEquals(candidate, function)))
        {
            throw new SmallLangException($"recursive inline function '{function.Name}' is not supported in the current runtime slice");
        }

        var outerLocals = CaptureLocals();
        var previousFunctions = _currentFunctions;
        _currentFunctions = CreateFunctionScope(_currentFunctions, function.LocalFunctions);
        _inlineFunctionStack.Add(function);
        try
        {
            if (function.InputType is null)
            {
                if (argument is not null)
                {
                    throw new SmallLangException($"function '{function.Name}' does not accept arguments");
                }
            }
            else
            {
                if (argument is null)
                {
                    throw new SmallLangException($"function '{function.Name}' expects exactly one argument");
                }

                EnsureRuntimeType(argument, function.InputType.Value, function.Name);
                _locals[function.InputName ?? "it"] = argument;
            }

            var value = EmitExpression(function.Body);
            EnsureRuntimeType(value, function.ReturnType, function.Name);
            return value;
        }
        finally
        {
            _inlineFunctionStack.RemoveAt(_inlineFunctionStack.Count - 1);
            _currentFunctions = previousFunctions;
            RestoreLocals(outerLocals);
        }
    }

    private RuntimeValue EmitFunctionCall(BoundFunction function, RuntimeValue? argument)
    {
        if (function.Kind is BoundFunctionKind.RuntimePrint or BoundFunctionKind.RuntimePrintLine)
        {
            if (argument is null)
            {
                throw new SmallLangException($"{function.Name} expects exactly one Text value");
            }

            EnsureRuntimeType(argument, BoundType.Text, function.Name);
            _mainOk = EmitWriteValue(argument, _mainOk);
            if (function.Kind == BoundFunctionKind.RuntimePrintLine)
            {
                _mainOk = EmitWriteText("\n", _mainOk);
            }

            return RuntimeUnit.Instance;
        }

        if (function.Kind == BoundFunctionKind.RuntimeReadInt)
        {
            if (argument is null)
            {
                throw new SmallLangException($"{function.Name} expects exactly one Text prompt");
            }

            EnsureRuntimeType(argument, BoundType.Text, function.Name);
            return EmitReadIntPrompt(argument);
        }

        if (function.Kind is BoundFunctionKind.RuntimeSeedRandom
            or BoundFunctionKind.RuntimeOpenIntWriter
            or BoundFunctionKind.RuntimeWriteInt
            or BoundFunctionKind.RuntimeCloseIntWriter
            or BoundFunctionKind.RuntimeOpenIntReader
            or BoundFunctionKind.RuntimeCloseIntReader)
        {
            return EmitRuntimeUnitIntrinsic(function, argument, function.Name);
        }

        if (function.Kind is BoundFunctionKind.RuntimeRandomBelow
            or BoundFunctionKind.RuntimeClosestInt)
        {
            if (argument is null)
            {
                throw new SmallLangException($"{function.Name} expects exactly one Int argument");
            }

            return EmitRuntimeIntIntrinsic(function, argument, function.Name);
        }

        if (function.Kind != BoundFunctionKind.User)
        {
            throw new SmallLangException($"function '{function.Name}' does not produce a runtime value");
        }

        if (function.IsStandardLibrary || function.IsLocal)
        {
            return EmitInlineFunctionCall(function, argument);
        }

        return function.ReturnType switch
        {
            BoundType.Text => EmitTextFunctionCall(function, argument),
            BoundType.Int => EmitIntFunctionCall(function, argument),
            BoundType.Bool => EmitBoolFunctionCall(function, argument),
            _ => throw new SmallLangException($"unsupported function return type {function.ReturnType}")
        };
    }

    private RuntimeText EmitTextFunctionCall(BoundFunction function, RuntimeValue? argument)
    {
        var aggregate = NextTemp("text");
        _functions.Append("  ")
            .Append(aggregate)
            .Append(" = call %smalllang.text ")
            .Append(SymbolForFunction(function.Name))
            .Append('(');
        AppendFunctionCallArgument(function, argument);
        _functions.AppendLine(")");

        var pointer = NextTemp("text_ptr");
        _functions.Append("  ")
            .Append(pointer)
            .Append(" = extractvalue %smalllang.text ")
            .Append(aggregate)
            .AppendLine(", 0");

        var length = NextTemp("text_len");
        _functions.Append("  ")
            .Append(length)
            .Append(" = extractvalue %smalllang.text ")
            .Append(aggregate)
            .AppendLine(", 1");

        return new RuntimeText(pointer, length);
    }

    private RuntimeInt EmitIntFunctionCall(BoundFunction function, RuntimeValue? argument)
    {
        var value = NextTemp("call");
        _functions.Append("  ")
            .Append(value)
            .Append(" = call i64 ")
            .Append(SymbolForFunction(function.Name))
            .Append('(');
        AppendFunctionCallArgument(function, argument);
        _functions.AppendLine(")");
        return new RuntimeInt(value);
    }

    private RuntimeBool EmitBoolFunctionCall(BoundFunction function, RuntimeValue? argument)
    {
        var value = NextTemp("call");
        _functions.Append("  ")
            .Append(value)
            .Append(" = call i1 ")
            .Append(SymbolForFunction(function.Name))
            .Append('(');
        AppendFunctionCallArgument(function, argument);
        _functions.AppendLine(")");
        return new RuntimeBool(value);
    }

    private void AppendFunctionCallArgument(BoundFunction function, RuntimeValue? argument)
    {
        if (function.InputType is null)
        {
            if (argument is not null)
            {
                throw new SmallLangException($"function '{function.Name}' does not accept arguments");
            }

            return;
        }

        if (argument is null)
        {
            throw new SmallLangException($"function '{function.Name}' expects exactly one argument");
        }

        switch (argument)
        {
            case RuntimeInt integer when function.InputType == BoundType.Int:
                _functions.Append("i64 ").Append(integer.ValueName);
                return;
            case RuntimeBool boolean when function.InputType == BoundType.Bool:
                _functions.Append("i1 ").Append(boolean.ValueName);
                return;
            default:
                throw new SmallLangException($"function '{function.Name}' expects {function.InputType} but received {argument.Type}");
        }
    }

    private static void EnsureRuntimeType(RuntimeValue value, BoundType expected, string path)
    {
        if (value.Type != expected)
        {
            throw new SmallLangException($"function '{path}' expects {expected} but received {value.Type}");
        }
    }

    private bool TryGetRuntimePrinterKind(BoundFunction function, out BoundFunctionKind kind)
    {
        if (function.Kind is BoundFunctionKind.RuntimePrint or BoundFunctionKind.RuntimePrintLine)
        {
            kind = function.Kind;
            return true;
        }

        if (TryGetRuntimeWrapperKind(function, out kind)
            && kind is BoundFunctionKind.RuntimePrint or BoundFunctionKind.RuntimePrintLine)
        {
            return true;
        }

        kind = default;
        return false;
    }

    private bool TryGetRuntimeWrapperKind(BoundFunction function, out BoundFunctionKind kind)
    {
        if (!function.IsStandardLibrary
            || function.Body is not FlowExpression flow
            || flow.Source is not NameExpression name
            || name.Name != (function.InputName ?? "it")
            || flow.Targets.Count != 1
            || !TryResolveFunction(flow.Targets[0].Path, out var target))
        {
            kind = default;
            return false;
        }

        if (target.Kind is BoundFunctionKind.RuntimePrint
            or BoundFunctionKind.RuntimePrintLine
            or BoundFunctionKind.RuntimeReadInt
            or BoundFunctionKind.RuntimeSeedRandom
            or BoundFunctionKind.RuntimeRandomBelow
            or BoundFunctionKind.RuntimeOpenIntWriter
            or BoundFunctionKind.RuntimeWriteInt
            or BoundFunctionKind.RuntimeOpenIntReader
            or BoundFunctionKind.RuntimeClosestInt)
        {
            kind = target.Kind;
            return true;
        }

        kind = default;
        return false;
    }

    private bool TryResolveFunction(IReadOnlyList<string> path, out BoundFunction function)
    {
        return _currentFunctions.TryGetValue(string.Join('.', path), out function!);
    }

    private static IReadOnlyDictionary<string, BoundFunction> CreateFunctionScope(
        IReadOnlyDictionary<string, BoundFunction> parentFunctions,
        IReadOnlyDictionary<string, BoundFunction> localFunctions)
    {
        if (localFunctions.Count == 0)
        {
            return parentFunctions;
        }

        var functions = new Dictionary<string, BoundFunction>(parentFunctions, StringComparer.Ordinal);
        foreach (var (name, function) in localFunctions)
        {
            functions[name] = function;
        }

        return functions;
    }

    private RuntimeValue ResolveLocal(string name)
    {
        return _locals.TryGetValue(name, out var value)
            ? value
            : throw new SmallLangException($"unknown runtime binding '{name}'");
    }

    private void EmitYield(RuntimeValue value, RuntimeBlockInvocation invocation)
    {
        var blockFunctionLocals = CaptureLocals();
        var blockFunctionFunctions = _currentFunctions;
        RestoreLocals(invocation.CallerLocals);
        _locals[invocation.ItemName] = value;
        _currentFunctions = invocation.CallerFunctions;
        try
        {
            EmitStatements(invocation.Body);
        }
        finally
        {
            _currentFunctions = blockFunctionFunctions;
            RestoreLocals(blockFunctionLocals);
        }
    }

    private Dictionary<string, RuntimeValue> CaptureLocals()
    {
        return new Dictionary<string, RuntimeValue>(_locals, StringComparer.Ordinal);
    }

    private void RestoreLocals(Dictionary<string, RuntimeValue> locals)
    {
        _locals.Clear();
        foreach (var (name, value) in locals)
        {
            _locals.Add(name, value);
        }
    }

    private GlobalString AddGlobalString(string text)
    {
        var bytes = Encoding.UTF8.GetBytes(text);
        var name = "@.smalllang.str." + _stringId.ToString(CultureInfo.InvariantCulture);
        _stringId++;
        _globals.Append(name)
            .Append(" = private unnamed_addr constant [")
            .Append(bytes.Length.ToString(CultureInfo.InvariantCulture))
            .Append(" x i8] c\"")
            .Append(EscapeLlvmBytes(bytes))
            .AppendLine("\", align 1");
        return new GlobalString(name, bytes.Length);
    }

    private static string GetPlainText(Expression expression, int line, int column)
    {
        if (expression is not StringExpression str)
        {
            throw new SmallLangException($"codegen error at {line}:{column}: expected a string literal");
        }

        var builder = new StringBuilder();
        foreach (var segment in str.Segments)
        {
            if (segment is TextSegment text)
            {
                builder.Append(text.Text);
                continue;
            }

            throw new SmallLangException($"codegen error at {line}:{column}: expected a plain string literal");
        }

        return builder.ToString();
    }

    private static long ParseNumber(NumberExpression expression)
    {
        return long.TryParse(
            expression.Text,
            NumberStyles.None,
            CultureInfo.InvariantCulture,
            out var value)
            ? value
            : throw new SmallLangException($"codegen error at {expression.Line}:{expression.Column}: integer literal is out of range");
    }

    private static string SymbolForFunction(string name)
    {
        var builder = new StringBuilder("@smalllang_fn_");
        foreach (var c in name)
        {
            builder.Append(char.IsLetterOrDigit(c) || c == '_' ? c : '_');
        }

        return builder.ToString();
    }

    private string NextTemp(string prefix)
    {
        var name = "%" + prefix + _tempId.ToString(CultureInfo.InvariantCulture);
        _tempId++;
        return name;
    }

    private string NextLabel(string prefix)
    {
        var name = prefix + _labelId.ToString(CultureInfo.InvariantCulture);
        _labelId++;
        return name;
    }

    private string CurrentTemp(string prefix)
    {
        return "%" + prefix + (_tempId - 1).ToString(CultureInfo.InvariantCulture);
    }

    private static string EscapeLlvmBytes(byte[] bytes)
    {
        var builder = new StringBuilder(bytes.Length);
        foreach (var b in bytes)
        {
            if (b is >= 0x20 and <= 0x7E && b != (byte)'\\' && b != (byte)'"')
            {
                builder.Append((char)b);
            }
            else
            {
                builder.Append('\\');
                builder.Append(b.ToString("X2", CultureInfo.InvariantCulture));
            }
        }

        return builder.ToString();
    }

    private sealed record GlobalString(string Name, int Length);

    private abstract record RuntimeValue(BoundType Type);

    private sealed record RuntimeText(string PointerName, string LengthName) : RuntimeValue(BoundType.Text);

    private sealed record RuntimeInt(string ValueName) : RuntimeValue(BoundType.Int);

    private sealed record RuntimeBool(string ValueName) : RuntimeValue(BoundType.Bool);

    private sealed record RuntimeUnit() : RuntimeValue(BoundType.Unit)
    {
        public static RuntimeUnit Instance { get; } = new();
    }

    private sealed record BlockResult(RuntimeValue? Value, string EndLabel);

    private sealed record RuntimeFlowBinding(string Name, RuntimeValue Value);

    private sealed record RuntimeFlowResult(RuntimeValue? Value, RuntimeFlowBinding? Binding, string Ok);

    private sealed record RuntimeBlockInvocation(
        string ItemName,
        IReadOnlyList<Statement> Body,
        Dictionary<string, RuntimeValue> CallerLocals,
        IReadOnlyDictionary<string, BoundFunction> CallerFunctions);
}
