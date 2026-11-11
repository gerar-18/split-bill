# Base stage
FROM node:22-alpine AS base
WORKDIR /usr/src/app
RUN apk add --no-cache libc6-compat

# Dependencies stage
FROM base AS deps
COPY package.json package-lock.json* ./
COPY prisma ./prisma/
RUN npm install

# Development stage
FROM base AS development
COPY --from=deps /usr/src/app/node_modules ./node_modules
COPY . .
RUN npx prisma generate
EXPOSE 3000
CMD ["npm", "run", "start:dev"]

# Build stage
FROM base AS builder
COPY --from=deps /usr/src/app/node_modules ./node_modules
COPY . .
RUN npx prisma generate
RUN npm run build
RUN npm prune --production

# Production stage
FROM base AS production
ENV NODE_ENV=production
COPY --from=builder /usr/src/app/node_modules ./node_modules
COPY --from=builder /usr/src/app/dist ./dist
COPY --from=builder /usr/src/app/prisma ./prisma
COPY package.json ./

EXPOSE 3000
CMD ["npm", "run", "start:prod"]
