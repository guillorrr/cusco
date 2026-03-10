FROM node:22-alpine

WORKDIR /app

# Install Angular CLI globally
RUN npm install -g @angular/cli

# Copy package files and install dependencies
COPY src/frontend/package*.json ./
RUN npm install

# Copy source code
COPY src/frontend/ .

EXPOSE 6006

CMD ["ng", "run", "cusco:storybook"]
