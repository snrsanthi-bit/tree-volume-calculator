// Configure Rails UJS
import Rails from "@rails/ujs"
Rails.start()

// Configure Turbolinks
import Turbolinks from "turbolinks"
Turbolinks.start()

// Import specific controllers
import HelloController from "./controllers/hello_controller"

// Eager load all controllers defined in the import map under controllers/*
import { Application } from "@hotwired/stimulus"
import { definitionsFromContext } from "@hotwired/stimulus-webpack-helpers"

window.Stimulus = Application.start()
const context = require.context("./controllers", true, /\.js$/)
Stimulus.load(definitionsFromContext(context))

import "./calculator"
