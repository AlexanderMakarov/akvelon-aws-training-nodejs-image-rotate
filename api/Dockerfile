FROM node:18-alpine AS builder
WORKDIR /app
COPY . .
# Build with "devDependencies" to have `tsc` installed.
RUN npm install
RUN npm run build

# Use 2nd stage to get rid of 48MB in resulting image (mostly typescript package).
FROM node:18-alpine AS final
WORKDIR /app
COPY --from=builder ./app/dist ./dist
COPY package*.json ./
RUN npm install --omit=dev
EXPOSE 3000
CMD [ "npm", "run", "start" ]
