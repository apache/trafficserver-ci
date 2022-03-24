Instructions on building and configuring cache-tests.

There are 2 parts for cache-tests.
* ATS test run on any docker jenkins build agent.
* Publishing server that runs on the `controller`.

These instructions and docker utilities exist on the `controller` in
`/opt/cache-tests/'.  There is this README, a Dockerfile and
 docker-compose.yml files.

For this to work a desired clone of the cache-tests git repo
`https://github.com/http-tests/cache-tests.git`
needs to reside in /opt/cache-tests/cache-tests on the `controller`.

Periodically this git repo should be updated which will require rebuilding
the cache-tests image: `controller.trafficserver.org/ats/cache-tests`
and restarting the Publishing server.

Currently the `debian:11` image from the ats docker repo is used
as the base.  On top of it is installed the npm utility which
is used to both run the tests and also publish the results on
port 8000 of the `controller`.  The above cache-tests git repo is added
into the docker image.  Building this image *MUST* be
done from `/opt/cache-tests` on the `controller`.

The Publishing server mounts this `/opt/cache-tests/cache-tests/results`
directory into its own copy of the cache-tests git repo and serves
that up.

In order to add or remove test run results the file
`/opt/cache-tests/cache-tests/results/index.mjs` should be edited
directly.  When upgrading the cache-tests git repo this file
will need to be rebased onto the updated pull.

An example update run:

```
cd /opt/cache-tests
docker-compose down server
cd /opt/cache-tests/cache-tests

# update the repo, merge the results/index.mjs changes
git stash ; git fetch ; git pull ; git stash apply

# rebuild and push cache-tests image
cd /opt/cache-tests
docker-compose build builder
docker tag <hash> controller.trafficserver.org:5000/ats/cache-tests
docker push controller.trafficserver.org:5000/ats/cache-tests

docker-compose up -d server
```

Also remember to clear/repull the cache-test images on the docker jenkins
agents.
