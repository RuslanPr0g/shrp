# shrp

Run C# instantly from your terminal — no `.csproj`, no `dotnet new`, no ceremony.

Built on [.NET 10's file-based apps](https://learn.microsoft.com/dotnet/core/tutorials/file-based-apps): `dotnet run some.cs` compiles and executes a single C# file directly, top-level-statements style.

## Requirements

- .NET SDK **10** or later (`dotnet --version`)
- zsh

## Install

```sh
git clone https://github.com/RuslanPr0g/shrp.git ~/.shrp
echo 'source ~/.shrp/cs.zsh' >> ~/.zshrc
source ~/.zshrc
```

## Usage

```sh
# Inline snippet
cs 'Console.WriteLine("hi");'

# Piped
echo 'Console.WriteLine(DateTime.Now);' | cs

# Multiline heredoc
cs <<'EOF'
for (int i = 0; i < 3; i++)
    Console.WriteLine($"line {i}");
EOF

# Run an existing file
cs script.cs

# Help
cs --help
```

With no arguments and nothing piped in, `cs` prints usage instead of hanging.

## How it works

`cs` writes your snippet to a temp `main.cs` in a scratch directory, runs `dotnet run <file>`, streams the output, then cleans up. Passing an existing `.cs` file skips the temp file and runs it in place.

## License

MIT
