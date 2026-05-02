REPO_NAME ?= $(shell basename -s .git "$$(git remote get-url origin 2>/dev/null)")
PORT ?= 8001

.PHONY: preview preview-gh-pages

preview:
	flutter build web --base-href /
	python3 -m http.server $(PORT) -d build/web

preview-gh-pages:
	flutter build web --base-href /$(REPO_NAME)/
	rm -rf "build/$(REPO_NAME)"
	mkdir -p "build/$(REPO_NAME)"
	cp -R build/web/. "build/$(REPO_NAME)/"
	python3 -m http.server $(PORT) -d build
