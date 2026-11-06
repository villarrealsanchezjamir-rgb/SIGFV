# syntax=docker/dockerfile:1

# Etapa 1: compilar y publicar el backend .NET
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY api/ ./api/
RUN dotnet publish api/src/SIGFV.Api/SIGFV.Api.csproj -c Release -o /app/publish

# Etapa 2: imagen final m��nima
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runner
ENV ASPNETCORE_ENVIRONMENT=Production
ENV PORT=3000
WORKDIR /app

COPY --from=build /app/publish ./
COPY public ./public

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD wget -qO- "http://127.0.0.1:${PORT}/api/health" >/dev/null || exit 1

ENTRYPOINT ["dotnet", "SIGFV.Api.dll"]