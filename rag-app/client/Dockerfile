FROM nginx:1.27-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html styles.css app.js markdown.js /usr/share/nginx/html/
COPY docker-entrypoint.sh /docker-entrypoint-rag.sh

RUN chmod +x /docker-entrypoint-rag.sh

ENV PORT=8080
ENV API_URL=http://localhost:8080

EXPOSE 8080

ENTRYPOINT ["/docker-entrypoint-rag.sh"]
