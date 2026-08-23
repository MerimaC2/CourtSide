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

    private static readonly Dictionary<string, byte[][]> SignaturesByContentType = new()
    {
        ["image/jpeg"] = [[0xFF, 0xD8, 0xFF]],
        ["image/png"] = [[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]],
        ["image/webp"] = [[0x52, 0x49, 0x46, 0x46]], // "RIFF" (WebP container)
    };

    public static async Task<(byte[] Data, string ContentType)> ReadAndValidateAsync(IFormFile file)
    {
        if (file.Length == 0)
            throw new BusinessException("Fajl je prazan.");
        if (file.Length > MaxSizeBytes)
            throw new BusinessException("Slika ne smije biti veća od 5 MB.");
        if (!SignaturesByContentType.TryGetValue(file.ContentType, out var signatures))
            throw new BusinessException("Dozvoljeni formati slike su JPEG, PNG i WebP.");

        await using var stream = file.OpenReadStream();
        using var memory = new MemoryStream();
        await stream.CopyToAsync(memory);
        var data = memory.ToArray();

        var matches = signatures.Any(sig => data.Length >= sig.Length && data.Take(sig.Length).SequenceEqual(sig));
        if (!matches)
            throw new BusinessException("Sadržaj fajla ne odgovara prijavljenom formatu slike.");

        return (data, file.ContentType);
    }
}
