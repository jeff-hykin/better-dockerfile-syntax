FROM node:12-alpine AS builder
ARG server_domain
ENV REACT_APP_SERVER_DOMAIN=${server_domain:-https://mymathapps.com}
WORKDIR /usr/src/myma-store
COPY . .
RUN ls /usr/src/myma-store/server/
RUN cd coronavirus-client \
	&& yarn \
	&& yarn build \
	&& cd ../server \
	&& yarn \
	&& yarn build


FROM node:12-slim
ARG environment
WORKDIR /myma-store
COPY --from=builder /usr/src/myma-store/coronavirus-client/build/ ./coronavirus-client/public
COPY --from=builder /usr/src/myma-store/server/ormconfig.js ./server
COPY --from=builder /usr/src/myma-store/server/build ./server/src
COPY --from=builder /usr/src/myma-store/server/node_modules ./server/node_modules
WORKDIR /myma-store/server
EXPOSE 8080
ENV NODE_ENV=${environment:-production}
RUN groupadd -r myma && useradd --no-log-init -r -g myma myma \
	&& [[ -v "${TYPEORM_SYNCHRONIZE}" ]] ./node_modules/.bin/typeorm schema:sync <-- this line
USER myma
CMD ["node", "./src/index.js"]