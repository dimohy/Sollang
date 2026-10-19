using System.Text;
using System.Text.Json;

static string Ranges(Func<char, bool> predicate)
{
    var builder = new StringBuilder();
    var start = -1;
    for (var value = 0; value <= 0x10000; value++)
    {
        var matches = value < 0x10000 && predicate((char)value);
        if (matches && start < 0) start = value;
        if (!matches && start >= 0)
        {
            builder.Append(start.ToString("X4"));
            builder.Append((value - 1).ToString("X4"));
            start = -1;
        }
    }
    return builder.ToString();
}

var letter = Ranges(char.IsLetter);
var continuation = Ranges(char.IsLetterOrDigit);
Console.WriteLine(JsonSerializer.Serialize(new
{
    schemaVersion = 1,
    runtime = System.Runtime.InteropServices.RuntimeInformation.FrameworkDescription,
    letterRangeCount = letter.Length / 8,
    continuationRangeCount = continuation.Length / 8,
    letterRangesHex = letter,
    continuationRangesHex = continuation
}));
