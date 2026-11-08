using CourtSide.Core.Exceptions;
using Microsoft.AspNetCore.Http;

namespace CourtSide.Services.Common;

/// <summary>
/// Validates uploaded image files by both declared content type and actual file signature
/// (magic bytes), so a renamed non-image file can't pass as one.
/// </summary>
public static class ImageValidation
{
    private const long MaxSizeBytes = 5 * 1024 * 1024;

    /// <summary>One part of a file signature: the bytes that must appear at a given offset.</summary>
    private readonly record struct SignaturePart(int Offset, byte[] Bytes);

    /// <summary>Every part must match for the file to count as that format.</summary>
    private static readonly Dictionary<string, SignaturePart[]> SignaturesByContentType = new(StringComparer.OrdinalIgnoreCase)
    {
        ["image/jpeg"] = [new(0, [0xFF, 0xD8, 0xFF])],
        ["image/png"] = [new(0, [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])],
        // RIFF is a generic container (also .wav, .avi), so the WEBP form marker decides.
        ["image/webp"] =
        [
            new(0, [0x52, 0x49, 0x46, 0x46]), // "RIFF"
            new(8, [0x57, 0x45, 0x42, 0x50]), // "WEBP"
        ],
    };

    public static async Task<(byte[] Data, string ContentType)> ReadAndValidateAsync(IFormFile file)
    {
        if (file.Length == 0)
            throw new BusinessException("Fajl je prazan.");
        if (file.Length > MaxSizeBytes)
            throw new BusinessException("Slika ne smije biti veća od 5 MB.");
        if (!SignaturesByContentType.TryGetValue(file.ContentType, out var signature))
            throw new BusinessException("Dozvoljeni formati slike su JPEG, PNG i WebP.");

        await using var stream = file.OpenReadStream();
        using var memory = new MemoryStream();
        await stream.CopyToAsync(memory);
        var data = memory.ToArray();

        var matches = signature.All(part =>
            data.Length >= part.Offset + part.Bytes.Length &&
            data.Skip(part.Offset).Take(part.Bytes.Length).SequenceEqual(part.Bytes));
        if (!matches)
            throw new BusinessException("Sadržaj fajla ne odgovara prijavljenom formatu slike.");

        return (data, file.ContentType);
    }
}
