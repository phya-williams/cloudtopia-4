FROM node:18-alpine

WORKDIR /app

COPY server.js .
COPY public/ ./public/

RUN npm install express @azure/storage-blob

ENV PORT=80
EXPOSE 80

CMD ["node", "server.js"]
