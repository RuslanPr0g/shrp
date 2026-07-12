#:package Microsoft.CodeAnalysis.CSharp.Scripting@4.*
#:package Microsoft.CodeAnalysis.Features@4.*
#:package Microsoft.CodeAnalysis.CSharp.Features@4.*
#:package Microsoft.CodeAnalysis.Workspaces.Common@4.*

using System;
using System.Collections.Generic;
using System.Linq;
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.Completion;
using Microsoft.CodeAnalysis.CSharp.Scripting;
using Microsoft.CodeAnalysis.Scripting;
using Microsoft.CodeAnalysis.Text;

var sentinel = "CS" + "SMART" + "EOM";

var scriptOptions = ScriptOptions.Default
    .WithReferences(typeof(object).Assembly, typeof(Console).Assembly, typeof(System.Linq.Enumerable).Assembly)
    .WithImports("System", "System.Linq", "System.Collections.Generic");

ScriptState<object>? state = null;

while (true)
{
    var verb = Console.ReadLine();
    if (verb is null || verb == "EXIT") break;

    switch (verb)
    {
        case "RUN":
            await HandleRunAsync(ReadUntilSentinel());
            break;
        case "COMPLETE":
            var cursor = int.Parse(Console.ReadLine() ?? "0");
            await HandleCompleteAsync(ReadUntilSentinel(), cursor);
            break;
        default:
            ReadUntilSentinel();
            WriteResponse("ERROR", $"unknown verb: {verb}");
            break;
    }
}

string ReadUntilSentinel()
{
    var lines = new List<string>();
    string? line;
    while ((line = Console.ReadLine()) is not null && line != sentinel)
        lines.Add(line);
    return string.Join("\n", lines);
}

void WriteResponse(string status, string body)
{
    Console.WriteLine(status);
    if (body.Length > 0) Console.WriteLine(body);
    Console.WriteLine(sentinel);
    Console.Out.Flush();
}

async Task HandleRunAsync(string code)
{
    // The script's own Console.WriteLine etc. would otherwise land on the
    // same stdout stream as our OK/ERROR/sentinel protocol lines and
    // desync the client's read loop. Capture it separately and fold it
    // into the response body instead.
    var realOut = Console.Out;
    var buffer = new System.Text.StringBuilder();
    using var captured = new System.IO.StringWriter(buffer);
    try
    {
        Console.SetOut(captured);
        state = state is null
            ? await CSharpScript.RunAsync(code, scriptOptions)
            : await state.ContinueWithAsync(code, scriptOptions);
        Console.SetOut(realOut);

        if (state.ReturnValue is not null)
            buffer.Append($"=> {state.ReturnValue}\n");

        WriteResponse("OK", buffer.ToString().TrimEnd('\n'));
    }
    catch (CompilationErrorException ex)
    {
        Console.SetOut(realOut);
        WriteResponse("ERROR", string.Join("; ", ex.Diagnostics));
    }
    catch (Exception ex)
    {
        Console.SetOut(realOut);
        WriteResponse("ERROR", ex.Message);
    }
}

async Task HandleCompleteAsync(string codeSoFar, int position)
{
    using var workspace = new AdhocWorkspace();
    var projectId = ProjectId.CreateNewId();
    var docId = DocumentId.CreateNewId(projectId);

    IEnumerable<MetadataReference> references = scriptOptions.MetadataReferences.Any()
        ? scriptOptions.MetadataReferences
        : new MetadataReference[]
        {
            MetadataReference.CreateFromFile(typeof(object).Assembly.Location),
            MetadataReference.CreateFromFile(typeof(Console).Assembly.Location),
            MetadataReference.CreateFromFile(typeof(System.Linq.Enumerable).Assembly.Location),
        };

    var projectInfo = ProjectInfo.Create(
        projectId,
        VersionStamp.Create(),
        "cs-smart",
        "cs-smart",
        LanguageNames.CSharp,
        metadataReferences: references,
        parseOptions: new Microsoft.CodeAnalysis.CSharp.CSharpParseOptions(kind: SourceCodeKind.Script),
        compilationOptions: new Microsoft.CodeAnalysis.CSharp.CSharpCompilationOptions(OutputKind.DynamicallyLinkedLibrary)
            .WithUsings(scriptOptions.Imports));

    var documentInfo = DocumentInfo.Create(
        docId,
        "cs-smart.csx",
        loader: TextLoader.From(TextAndVersion.Create(SourceText.From(codeSoFar), VersionStamp.Create())),
        sourceCodeKind: SourceCodeKind.Script);

    var solution = workspace.CurrentSolution
        .AddProject(projectInfo)
        .AddDocument(documentInfo);

    var document = solution.GetDocument(docId)!;
    var completionService = CompletionService.GetService(document);
    if (completionService is null)
    {
        WriteResponse("CANDIDATES", "");
        return;
    }

    var results = await completionService.GetCompletionsAsync(document, position);
    var suggestions = results.ItemsList.Select(i => i.DisplayText).Distinct();
    WriteResponse("CANDIDATES", string.Join("\n", suggestions));
}
