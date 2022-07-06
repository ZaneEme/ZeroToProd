# cargo - chef lets us do a `pip install -r requirements.txt` type thing
FROM lukemathwalker/cargo-chef:latest-rust-1.59.0 as chef

WORKDIR /app

RUN apt update && apt install lld clang -y

FROM chef as planner

COPY . .
# build a pseudo `requirements.txt`
RUN cargo chef prepare --recipe-path recipe.json

# builder stage
FROM chef as builder

COPY --from=planner /app/recipe.json recipe.json

# build the dependencies without the project itself
RUN cargo chef cook --release --recipe-path recipe.json

COPY . .

ENV SQLX_OFFLINE true

# build the project itself
RUN cargo build --release --bin zero_to_prod

# runtime stage
FROM debian:bullseye-slim AS runtime

WORKDIR /app

RUN apt-get update -y \
    && apt-get install -y --no-install-recommends openssl ca-certificates \
    # clean up system
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/target/release/zero_to_prod zero_to_prod

COPY configuration configuration

ENV APP_ENVIRONMENT production

ENTRYPOINT ["./zero_to_prod"]
