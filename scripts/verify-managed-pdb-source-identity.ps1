[CmdletBinding()]
param(
    [Parameter(Mandatory)][string[]]$AssemblyPath,
    [Parameter(Mandatory)][string[]]$RequiredSource,
    [Parameter(Mandatory)][string]$OutputJson
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
# Portable PDB checksums attest compiled documents; they are not a new build
# or evidence that an entire compiler pipeline has passed.
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Linq;
using System.Reflection.Metadata;
using System.Reflection.PortableExecutable;
using System.Security.Cryptography;
public static class ManagedPdbSourceIdentity {
 public static object[] Read(string assembly) {
  using var stream=File.OpenRead(assembly); using var pe=new PEReader(stream);
  var entry=pe.ReadDebugDirectory().Single(x=>x.Type==DebugDirectoryEntryType.CodeView);
  var cv=pe.ReadCodeViewDebugDirectoryData(entry);
  using var ps=File.OpenRead(Path.ChangeExtension(assembly,".pdb"));
  using var provider=MetadataReaderProvider.FromPortablePdbStream(ps);
  var reader=provider.GetMetadataReader(); var id=reader.DebugMetadataHeader.Id.ToArray();
  if(cv.Guid!=new Guid(id.Take(16).ToArray()) || entry.Stamp!=BitConverter.ToUInt32(id,16) || cv.Age!=1)
   throw new InvalidDataException("MANAGED_PDB_IDENTITY_MISMATCH");
  return reader.Documents.Select(handle=> {
   var document=reader.GetDocument(handle); var algorithm=reader.GetGuid(document.HashAlgorithm);
   string name=algorithm==new Guid("8829d00f-11b8-4213-878b-770e8597ac16")?"SHA256":
    algorithm==new Guid("ff1816ec-aa5e-4d10-87f7-6f4963833460")?"SHA1":
    throw new InvalidDataException("MANAGED_PDB_HASH_ALGORITHM_UNSUPPORTED");
   return (object)new {path=reader.GetString(document.Name),algorithm=name,
    checksum=Convert.ToHexString(reader.GetBlobBytes(document.Hash))};
  }).ToArray();
 }
}
'@
$documents = @{}
$binaries = @()
$binaryHashes = @{}
foreach ($assembly in $AssemblyPath) {
    $path = (Resolve-Path -LiteralPath $assembly).Path
    $pdb = [IO.Path]::ChangeExtension($path, '.pdb')
    $binaryHashes[$path] = (Get-FileHash -LiteralPath $path).Hash
    $binaryHashes[$pdb] = (Get-FileHash -LiteralPath $pdb).Hash
    $rows = @([ManagedPdbSourceIdentity]::Read($path))
    foreach ($row in $rows) {
        $source = [IO.Path]::GetFullPath($row.path)
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "MANAGED_PDB_DOCUMENT_MISSING: $source" }
        if ((Get-FileHash -LiteralPath $source -Algorithm $row.algorithm).Hash -cne $row.checksum) {
            throw "MANAGED_PDB_DOCUMENT_DRIFT: $source"
        }
        $sha = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
        if ($documents.ContainsKey($source) -and $documents[$source] -cne $sha) { throw 'MANAGED_PDB_DOCUMENT_CONFLICT' }
        $documents[$source] = $sha
    }
    $binaries += [ordered]@{path=$path;sha256=$binaryHashes[$path];
        pdbPath=$pdb;pdbSha256=$binaryHashes[$pdb];documentCount=$rows.Count;identityMatches=$true}
}
$required = [ordered]@{}
foreach ($source in $RequiredSource) {
    $path = [IO.Path]::GetFullPath($source)
    if (-not $documents.ContainsKey($path)) { throw "MANAGED_PDB_REQUIRED_SOURCE_NOT_COMPILED: $path" }
    $required[$path] = $documents[$path]
}
foreach ($hashes in @($documents, $binaryHashes)) {
    foreach ($entry in $hashes.GetEnumerator()) {
        if ((Get-FileHash -LiteralPath $entry.Key).Hash -cne $entry.Value) { throw "MANAGED_PDB_INPUT_CHANGED: $($entry.Key)" }
    }
}
$result = [ordered]@{schemaVersion=1;status='passed';observedAt=[DateTimeOffset]::UtcNow.ToString('o');
    evidenceMode='portable-pdb-document-checksums';inputStable=$true;completed=$required.Count;total=$required.Count;
    compiledDocumentCount=$documents.Count;binaries=$binaries;sourceHashesAttested=$required;
    limitation='Source identity only; not phase behavior, build start/end capture, or compiler completion.'}
$destination = [IO.Path]::GetFullPath($OutputJson)
if ($documents.ContainsKey($destination) -or $binaryHashes.ContainsKey($destination) -or $destination -ieq $PSCommandPath) {
    throw 'MANAGED_PDB_OUTPUT_OVERLAPS_INPUT'
}
[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))
[IO.File]::WriteAllText($destination, ($result | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
Write-Output "PASS managed PDB required sources $($required.Count)/$($required.Count); compiled documents $($documents.Count)"
