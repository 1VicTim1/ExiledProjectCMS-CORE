# Build stage
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# Copy project files
COPY ["ExiledProjectCMS.API/ExiledProjectCMS.API.csproj", "ExiledProjectCMS.API/"]
COPY ["ExiledProjectCMS.Application/ExiledProjectCMS.Application.csproj", "ExiledProjectCMS.Application/"]
COPY ["ExiledProjectCMS.Core/ExiledProjectCMS.Core.csproj", "ExiledProjectCMS.Core/"]
COPY ["ExiledProjectCMS.Infrastructure/ExiledProjectCMS.Infrastructure.csproj", "ExiledProjectCMS.Infrastructure/"]

# Restore dependencies
RUN dotnet restore "ExiledProjectCMS.API/ExiledProjectCMS.API.csproj"

# Copy all source files
COPY . .

# Build the application
WORKDIR "/src/ExiledProjectCMS.API"
RUN dotnet build "ExiledProjectCMS.API.csproj" -c Release -o /app/build

# Publish the application
FROM build AS publish
RUN dotnet publish "ExiledProjectCMS.API.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS runtime
WORKDIR /app

# Create non-root user
RUN adduser --disabled-password --gecos '' appuser && \
    chown -R appuser /app
USER appuser

# Copy published application
COPY --from=publish /app/publish .

# Create directories for plugins and uploads
RUN mkdir -p /app/Plugins /app/Uploads /app/Logs

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:80/health || exit 1

# Environment variables
ENV ASPNETCORE_ENVIRONMENT=Production
ENV ASPNETCORE_URLS=http://+:80
ENV DOTNET_RUNNING_IN_CONTAINER=true
ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false

# Expose port
EXPOSE 80

ENTRYPOINT ["dotnet", "ExiledProjectCMS.API.dll"]