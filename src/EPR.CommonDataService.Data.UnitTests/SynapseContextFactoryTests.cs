using Microsoft.EntityFrameworkCore;

namespace EPR.CommonDataService.Data.UnitTests;

[TestClass]
public class SynapseContextFactoryTests
{
    [TestMethod]
    public void CreateDbContext_ShouldReturnSynapseContext_WhenCalledWithArguments()
    {
        // Arrange
        const string ConnectionString = "Server=tcp:test.sql.net;Initial Catalog=test;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;Authentication=Active Directory Default;";
        var factory = new SynapseContextFactory();
        var args = new[] { ConnectionString };

        // Act
        var context = factory.CreateDbContext(args);

        // Assert
        context.Should().NotBeNull();
        context.Database.GetDbConnection().ConnectionString.Should().Be(ConnectionString);
    }

    [TestMethod]
    public void CreateDbContext_ShouldReturnSynapseContext_WhenCalledWithoutArguments()
    {
        // Arrange
        var factory = new SynapseContextFactory();
        var args = Array.Empty<string>();

        // Act
        var context = factory.CreateDbContext(args);

        // Assert
        context.Should().NotBeNull();
    }

    [TestMethod]
    public void CreateDbContext_ShouldThrowArgumentNullException_WhenCalledWithNullArguments()
    {
        // Arrange
        var factory = new SynapseContextFactory();

        // Act
        Action act = () => factory.CreateDbContext(null!);

        // Assert
        act.Should().Throw<NullReferenceException>();
    }
}