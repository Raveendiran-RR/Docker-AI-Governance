# syntax=docker/dockerfile:1

# Build a self-contained image that serves THIS repo's labs. It bases on the
# prebuilt Simspace runtime and swaps in your labs/ directory. Labs are loaded at
# runtime, so there's no app rebuild — only the labs.json catalog is generated
# (with the authoring image) so the runtime knows what labs exist.
#
#   docker build -t my-lab .
#   docker run --rm -p 8080:80 my-lab      # open http://localhost:8080
#
# Pin the images to a released version for reproducible builds (use the SAME tag
# for both so runtime + authoring match):
#   docker build \
#     --build-arg RUNTIME_IMAGE=dockersamples/simspace:1 \
#     --build-arg AUTHORING_IMAGE=dockersamples/simspace-authoring:1 \
#     -t my-lab .

ARG RUNTIME_IMAGE=dockersamples/simspace:latest
ARG AUTHORING_IMAGE=dockersamples/simspace-authoring:latest

# Generate labs.json from labs/*/labspace.yaml using the authoring image.
FROM ${AUTHORING_IMAGE} AS catalog
WORKDIR /work
COPY labs/ ./labs/
RUN npm run generate-catalog -- /work/labs /work/labs.json

FROM ${RUNTIME_IMAGE}
# Replace the runtime image's sample labs + catalog with this repo's.
RUN rm -rf /usr/share/nginx/html/labs /usr/share/nginx/html/labs.json
COPY labs/ /usr/share/nginx/html/labs/
COPY --from=catalog /work/labs.json /usr/share/nginx/html/labs.json
