using System.Text;

namespace Sollang.Compiler.CodeGen;

internal interface ITextOutputSink
{
    void Write(string text);

    void Write(ReadOnlySpan<char> text);
}

internal sealed class TextWriterOutputSink(TextWriter writer) : ITextOutputSink
{
    public void Write(string text)
    {
        writer.Write(text);
    }

    public void Write(ReadOnlySpan<char> text)
    {
        writer.Write(text);
    }
}

internal sealed class MemoryOutputSink : ITextOutputSink
{
    private abstract class Segment;

    private sealed class TextSegment(StringBuilder buffer) : Segment
    {
        public StringBuilder Buffer { get; } = buffer;
    }

    private sealed class InsertionSegment(MemoryOutputSink sink) : Segment
    {
        public MemoryOutputSink Sink { get; } = sink;
    }

    private readonly List<Segment> _segments = [];
    private StringBuilder _current = new();

    public void Write(string text)
    {
        _current.Append(text);
    }

    public void Write(ReadOnlySpan<char> text)
    {
        _current.Append(text);
    }

    public void WriteLine(string line = "")
    {
        _current.Append(line);
        _current.Append(Environment.NewLine);
    }

    public MemoryOutputSink CreateInsertionPoint()
    {
        CommitCurrent();
        var insertion = new MemoryOutputSink();
        _segments.Add(new InsertionSegment(insertion));
        return insertion;
    }

    public void CopyTo(ITextOutputSink destination)
    {
        ArgumentNullException.ThrowIfNull(destination);
        if (ReferenceEquals(this, destination))
        {
            throw new ArgumentException("a memory output sink cannot copy into itself", nameof(destination));
        }

        CommitCurrent();
        foreach (var segment in _segments)
        {
            if (segment is TextSegment text)
            {
                foreach (var chunk in text.Buffer.GetChunks())
                {
                    destination.Write(chunk.Span);
                }
            }
            else
            {
                ((InsertionSegment)segment).Sink.CopyTo(destination);
            }
        }
    }

    public override string ToString()
    {
        var destination = new StringBuilder();
        CopyTo(new StringBuilderOutputSink(destination));
        return destination.ToString();
    }

    private void CommitCurrent()
    {
        if (_current.Length == 0)
        {
            return;
        }

        _segments.Add(new TextSegment(_current));
        _current = new StringBuilder();
    }

    private sealed class StringBuilderOutputSink(StringBuilder builder) : ITextOutputSink
    {
        public void Write(string text)
        {
            builder.Append(text);
        }

        public void Write(ReadOnlySpan<char> text)
        {
            builder.Append(text);
        }
    }
}
