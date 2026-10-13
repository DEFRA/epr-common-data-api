using System.Diagnostics.CodeAnalysis;
using EPR.CommonDataService.Api.Features.PayCal.Fss.v1.BillingOrganisations;
using EPR.CommonDataService.Api.Features.PayCal.Fss.v1.BillingOrganisations.Get;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

namespace EPR.CommonDataService.Api.UnitTests.Features.PayCal.Fss.v1.BillingOrganisations;

[ExcludeFromCodeCoverage]
[TestClass]
public class BillingOrganisationsControllerTests
{
    private Mock<IGetBillingOrganisationsRequestHandler> _mockRequestHandler = null!;
    private BillingOrganisationsController _controller = null!;

    [TestInitialize]
    public void Setup()
    {
        _mockRequestHandler = new Mock<IGetBillingOrganisationsRequestHandler>();

        _controller = new BillingOrganisationsController(
            _mockRequestHandler.Object,
            new Mock<ILogger<BillingOrganisationsController>>().Object)
        {
            ControllerContext = new ControllerContext
            {
                HttpContext = new DefaultHttpContext()
            }
        };
    }

    [TestMethod]
    public async Task Get_ShouldReturnOkWithHandlerResponse()
    {
        // Arrange
        var request = new GetBillingOrganisationsRequest
        {
            FinancialYear = "2025-26",
            ApprovedAfter = new DateTimeOffset(2025, 6, 1, 0, 0, 0, TimeSpan.Zero)
        };
        using var cts = new CancellationTokenSource();

        var response = new GetBillingOrganisationsResponse { OrganisationsDetails = [] };

        _mockRequestHandler
            .Setup(h => h.Handle(request, cts.Token))
            .ReturnsAsync(response);

        // Act
        var result = await _controller.Get(request, cts.Token);

        // Assert
        result.Should().BeOfType<OkObjectResult>().Which.Value.Should().BeSameAs(response);
    }
}
