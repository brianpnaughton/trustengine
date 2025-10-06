# Use the official PostgreSQL image as the base
FROM node:14-alpine3.16

# Install necessary dependencies and extensions
RUN npm install pm2

RUN apk update && \
    apk add git 

RUN cd / && \
    git clone https://github.com/apache/age-viewer.git

WORKDIR /age-viewer

RUN npm install pm2 && \
    npm run setup

EXPOSE 3000

CMD ["npm", "run", "start"]
