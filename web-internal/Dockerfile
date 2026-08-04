FROM nginxinc/nginx-unprivileged:alpine

USER root
RUN mkdir -p /var/log/nginx /var/cache/nginx /var/run \
    && chown -R 101:101 /var/log/nginx /var/cache/nginx /var/run
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY html/ /usr/share/nginx/html/
RUN chown -R 101:101 /usr/share/nginx/html /etc/nginx/conf.d/default.conf
USER 101
EXPOSE 8080
