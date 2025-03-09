# Stage 1: Build the Flutter web app
FROM dart:stable AS build

WORKDIR /app

# Install Flutter
RUN git clone https://github.com/flutter/flutter.git /flutter
ENV PATH="/flutter/bin:${PATH}"
RUN flutter doctor
RUN flutter channel stable
RUN flutter upgrade

# Copy the app files to the container
COPY . .

# Build the app for the web
RUN flutter pub get
RUN flutter build web --release

# Stage 2: Serve the app using Nginx
FROM nginx:alpine

# Copy the build output to the nginx server
COPY --from=build /app/build/web /usr/share/nginx/html

# Copy a custom nginx config if needed
# COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"] 