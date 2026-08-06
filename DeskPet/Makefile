.PHONY: app debug run install clean

app:
	@bash Scripts/make_app.sh release

debug:
	@bash Scripts/make_app.sh debug

run: app
	@open build/DeskPet.app

install: app
	@rm -rf /Applications/DeskPet.app
	@cp -R build/DeskPet.app /Applications/DeskPet.app
	@echo "Instalada en /Applications/DeskPet.app"

clean:
	@rm -rf .build build
