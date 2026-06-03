# ── Lucky5 consolidated Dockerfile ───────────────────────────────────────────
# Multi-stage build: Next.js web client + .NET 9 API -> single deployable image
#
# Build:  docker build -t lucky5-v7 .
# Run:    docker run -p 8080:8080 lucky5-v7
#         docker run -p 8080:8080 -e JWT__SIGNING_KEY=your-secret lucky5-v7

# ── Stage 1: Web client build ───────────────────────────────────────────────
FROM node:22-alpine AS web
WORKDIR /web
COPY src/web/package.json src/web/pnpm-lock.yaml* ./
RUN corepack enable && pnpm install --frozen-lockfile
COPY src/web/ ./
ENV NEXT_EXPORT=1 NODE_ENV=production
RUN pnpm run build

# ── Stage 2: .NET API build ─────────────────────────────────────────────────
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS api-build
WORKDIR /src
COPY server/ ./server/
RUN dotnet restore server/src/Lucky5.Api/Lucky5.Api.csproj
RUN dotnet publish server/src/Lucky5.Api/Lucky5.Api.csproj -c Release -o /app/publish /p:UseAppHost=false --no-restore

# ── Stage 3: Runtime ────────────────────────────────────────────────────────
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS runtime
WORKDIR /app

# Copy API
COPY --from=api-build /app/publish ./

# Copy web client static export into wwwroot
COPY --from=web /web/out ./wwwroot/

# Create data directory for optional file persistence
RUN mkdir -p /app/data

ENV ASPNETCORE_URLS=http://0.0.0.0:8080 \
    ASPNETCORE_ENVIRONMENT=Production \
    JWT__SIGNING_KEY=dev-signing-key-change-me-in-production

EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD curl -f http://localhost:8080/health/live || exit 1

ENTRYPOINT ["dotnet", "Lucky5.Api.dll"]