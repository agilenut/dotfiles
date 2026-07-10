// Palette sample: C# — comments, strings, numbers, keywords, types, xml-doc.
using System;

namespace Palette;

/// <summary>Builds greetings for the palette demo.</summary>
public sealed class Greeter(string name = "world")
{
    private const int MaxRetries = 3;

    public string Greet()
    {
        var sb = new System.Text.StringBuilder();
        for (var i = 0; i < MaxRetries; i++)
        {
            sb.AppendLine($"hello {name} ({i})");
        }
        return sb.ToString();
    }
}
