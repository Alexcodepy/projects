import AppKit

// DeskPet arranca como aplicación accesoria (sin icono en el Dock).
// El fichero se llama main.swift, así que no se puede usar @main:
// construimos la NSApplication a mano.
let application = NSApplication.shared
let deskPetDelegate = AppDelegate()
application.delegate = deskPetDelegate
application.setActivationPolicy(.accessory)
application.run()
