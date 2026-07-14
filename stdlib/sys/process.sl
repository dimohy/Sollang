namespace sys.process

arguments: -> Arguments uses Process = intrinsic

environment name: Text -> Option<Text> uses Environment = intrinsic

# Runs one executable directly without a shell. The first item is the program
# and remaining items are literal argv entries.
run argv: [Text; ~] -> Result<Int, Text> uses Process = intrinsic
