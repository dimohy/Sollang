namespace sys.process

# Runs one executable directly and connects only its standard output to a
# newly created or truncated file. Arguments remain literal argv entries; no
# shell parsing or command-string quoting is introduced.
public struct RunToFileRequest {
    argv: [Text; ~]
    output: Text
}

arguments: -> Arguments uses Process = intrinsic

environment name: Text -> Option<Text> uses Environment = intrinsic

# Runs one executable directly without a shell. The first item is the program
# and remaining items are literal argv entries.
run argv: [Text; ~] -> Result<Int, Text> uses Process = intrinsic

runToFile request: RunToFileRequest -> Result<Int, Text> uses Process, File = intrinsic
