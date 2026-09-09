using CourtSide.Core.Dto;
using FluentValidation;

namespace CourtSide.Services.Validation;

public class NewsUpsertDtoValidator : AbstractValidator<NewsUpsertDto>
{
    public NewsUpsertDtoValidator()
    {
        RuleFor(x => x.Title).NotEmpty().WithMessage("Naslov je obavezan.")
            .MaximumLength(150).WithMessage("Naslov može imati najviše 150 znakova.");
        RuleFor(x => x.Text).NotEmpty().WithMessage("Tekst obavijesti je obavezan.")
            .MaximumLength(4000).WithMessage("Tekst može imati najviše 4000 znakova.");
    }
}
