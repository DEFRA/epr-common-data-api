using System.Diagnostics.CodeAnalysis;
using EPR.CommonDataService.Api.Features.PayCal.v1.Organisations;
using EPR.CommonDataService.Api.Features.PayCal.v1.Organisations.StreamOut;
using EPR.CommonDataService.Api.Infrastructure;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

namespace EPR.CommonDataService.Api.UnitTests.Features.PayCal.v1.Organisations;

[ExcludeFromCodeCoverage]
[TestClass]
public class OrganisationsControllerTests
{
    private Mock<IStreamOrganisationsRequestHandler> _mockRequestHandler = null!;
    private Mock<ILogger<OrganisationsController>> _mockLogger = null!;
    private OrganisationsController _controller = null!;

    [TestInitialize]
    public void Setup()
    {
        _mockRequestHandler = new Mock<IStreamOrganisationsRequestHandler>();
        _mockLogger = new Mock<ILogger<OrganisationsController>>();

        _controller = new OrganisationsController(
            _mockRequestHandler.Object,
            _mockLogger.Object)
        {
            ControllerContext = new ControllerContext
            {
                HttpContext = new DefaultHttpContext()
            }
        };
    }

    [TestMethod]
    public void StreamOut_ShouldReturnNdJsonStreamResult()
    {
        // Arrange
        var request = new StreamOrganisationsRequest { RelativeYear = 2025, CutOffDate = null };

        var orgResponses = new List<OrganisationResponse>
        {
            new()
            {
                OrganisationId = 1,
                SubsidiaryId = null,
                OrganisationName = "Test Org",
                TradingName = "Test Trading",
                StatusCode = "Active",
                ErrorCode = null,
                JoinerDate = "2024-01-01",
                LeaverDate = null,
                ObligationStatus = "Obligated",
                NumDaysObligated = 365,
                SubmitterId = "b2c3d4e5-f6a7-8901-bcde-f12345678901"
            }
        };

        _mockRequestHandler
            .Setup(h => h.Handle(2025, null))
            .Returns(orgResponses.ToAsyncEnumerable());

        // Act
        var result = _controller.StreamOut(request, CancellationToken.None);

        // Assert
        result.Should().BeOfType<NdJsonStreamResult<OrganisationResponse>>();
    }
}
