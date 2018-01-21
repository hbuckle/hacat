FROM busybox
RUN wget -O nyan https://github.com/cristurm/nyan-cat/archive/gh-pages.zip
RUN unzip nyan
RUN mv nyan-cat-gh-pages /www
EXPOSE 8000
CMD httpd -p 8000 -h /www; tail -f /dev/null