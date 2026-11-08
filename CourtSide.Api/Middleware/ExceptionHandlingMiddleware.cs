using CourtSide.Core.Exceptions;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

namespace CourtSide.Api.Middleware;

/// <summary>Maps domain exceptions to HTTP status codes and hides internal errors from clients.</summary>
public class ExceptionHandlingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<ExceptionHandlingMiddleware> _logger;

    public ExceptionHandlingMiddleware(RequestDelegate next, ILogger<ExceptionHandlingMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (NotFoundException ex)
        {
            await WriteAsync(context, StatusCodes.Status404NotFound, ex.Message);
        }
        catch (ForbiddenException ex)
        {
            await WriteAsync(context, StatusCodes.Status403Forbidden, ex.Message);
        }
        catch (BusinessException ex)
        {
            await WriteAsync(context, StatusCodes.Status400BadRequest, ex.Message);
        }
        catch (DbUpdateException ex) when (IsConstraintViolation(ex))
        {
            // A constraint the services did not catch first — a missing reference, a duplicate.
            // The request is what is wrong, so it is answered as such rather than as a server fault.
            // Only constraint violations qualify: a deadlock or a timeout is the server's problem
            // and must keep falling through to 500, where it is logged as an error.
            _logger.LogWarning(ex, "Zapis odbijen na {Method} {Path}", context.Request.Method, context.Request.Path);
            await WriteAsync(context, StatusCodes.Status400BadRequest,
                "Podatke nije moguće sačuvati. Provjerite unos i povezane zapise.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Neobrađena greška na {Method} {Path}", context.Request.Method, context.Request.Path);
            await WriteAsync(context, StatusCodes.Status500InternalServerError,
                "Došlo je do greške na serveru. Pokušajte ponovo kasnije.");
        }
    }

    /// <summary>
    /// SQL Server numbers for a foreign key that points at nothing (547) and for a duplicate in a
    /// unique index (2601, 2627). Those say the submitted data is wrong; everything else that can
    /// fail a save — deadlocks, timeouts — is a server problem and is reported as one.
    /// </summary>
    private static bool IsConstraintViolation(DbUpdateException ex) =>
        ex.InnerException is SqlException sql && sql.Number is 547 or 2601 or 2627;

    private static async Task WriteAsync(HttpContext context, int statusCode, string message)
    {
        context.Response.StatusCode = statusCode;
        context.Response.ContentType = "application/json";
        await context.Response.WriteAsJsonAsync(new { message });
    }
}
