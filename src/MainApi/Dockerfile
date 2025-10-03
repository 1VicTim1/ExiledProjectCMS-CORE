# Multi-stage build for MainApi (.NET 8)
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy project files
COPY MainApi.csproj ./
RUN dotnet restore "MainApi.csproj"

# Copy the rest and publish
COPY . ./
RUN dotnet publish "MainApi.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Runtime image
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app

# Copy published output
COPY --from=build /app/publish ./

# Listen on 8080 inside container
ENV ASPNETCORE_URLS=http://0.0.0.0:8080
EXPOSE 8080

ENTRYPOINT ["dotnet", "MainApi.dll"]
