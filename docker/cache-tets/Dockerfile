FROM node:16
EXPOSE 8000

RUN git clone https://github.com/http-tests/cache-tests.git
RUN cd cache-tests && npm i
CMD cd cache-tests && npm run server
