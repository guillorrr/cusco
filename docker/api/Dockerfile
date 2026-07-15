FROM node:22-alpine

WORKDIR /app

# Install dependencies for Prisma and general tooling
RUN apk add --no-cache openssl bash

# Copy package files
COPY src/api/package*.json ./

# Install dependencies
RUN npm install

# Copy source code
COPY src/api/ .

# Generate Prisma client. Must not be silenced: if it fails, the image ships
# without a client and the only symptom is the API failing to compile at
# runtime, with nothing in the build log pointing here.
RUN npx prisma generate

EXPOSE 3000

CMD ["npm", "run", "start:dev"]
