# Frontend - Nginx
FROM nginx:alpine AS frontend
COPY index.html /usr/share/nginx/html/index.html
COPY nginx.conf /etc/nginx/nginx.conf

# Backend - Node.js
FROM node:18-alpine AS backend
WORKDIR /app
COPY package.json .
RUN npm install
COPY backend.js .
EXPOSE 3000
CMD ["node", "backend.js"]