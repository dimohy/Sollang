namespace sys.file

import sys.runtime as rt

# File is an affine native resource. Its private token cannot be constructed or
# copied by user code, and leaving the owner scope closes it deterministically.
public struct File {
    token: UInt64
}

# FileWriter is a separate affine capability, so read-only and write-only
# handles cannot be mixed accidentally. openWrite creates or truncates a file.
# Its syncAsync flow member is a durable-data barrier, not a user-buffer flush.
public struct FileWriter {
    token: UInt64
}

openRead path: Text -> Result<File, Text> uses File = intrinsic

openReadAsync path: Text -> async Result<File, Text> uses File = intrinsic

openWrite path: Text -> Result<FileWriter, Text> uses File = intrinsic

openWriteAsync path: Text -> async Result<FileWriter, Text> uses File = intrinsic

openIntWriter path: Text -> Unit uses File {
    path -> rt.openIntWriter
}

writeInt value: Int -> Unit uses File {
    value -> rt.writeInt
}

closeIntWriter: -> Unit uses File {
    rt.closeIntWriter
}

openIntReader path: Text -> Unit uses File {
    path -> rt.openIntReader
}

closestInt target: Int -> Int uses File {
    target -> rt.closestInt
}

closeIntReader: -> Unit uses File {
    rt.closeIntReader
}

# Generic canonical binary writer. Existing Int-specific names remain for the
# sorted Int64 demo format.
openWriter path: Text -> Unit uses File = intrinsic

write<T> value: T -> Unit uses File = intrinsic

closeWriter: -> Unit uses File = intrinsic

# Generic canonical binary reader. Ok(None) is clean EOF; partial scalars,
# invalid Bool/CodePoint encodings, and operating-system failures return
# "truncated", "invalid", and "io" errors.
openReader path: Text -> Unit uses File = intrinsic

read<T>: -> Result<Option<T>, Text> uses File = intrinsic

# Asynchronous scalar reads use the shared native file worker. The operation
# returns an affine Task and therefore composes with the ordinary await and
# cancellation rules without exposing callbacks or executor handles.
readAsync<T>: -> async Result<Option<T>, Text> uses File = intrinsic

closeReader: -> Unit uses File = intrinsic
