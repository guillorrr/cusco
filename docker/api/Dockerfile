FROM node:20-alpine

WORKDIR /app

# Install dependencies for Prisma and general tooling
RUN apk add --no-cache openssl bash

# Copy package files
COPY src/api/package*.json ./

# Install dependencies
RUN npm install

# Copy source code
COPY src/api/ .

# Generate Prisma client
RUN npx prisma generate 2>/dev/null || true

EXPOSE 3000

CMD ["npm", "run", "start:dev"]
