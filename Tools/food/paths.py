# -*- coding: utf-8 -*-
"""Repository paths of the food tools, worked out from this folder (Tools/food), so every script
runs the same from any working directory."""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
CORE = os.path.join(ROOT, "Packages", "AboutHerCore")
FOODDB = os.path.join(CORE, "Sources", "AboutHerCore", "Resources", "FoodDB.json")
MEAL_PARSER = os.path.join(CORE, "Sources", "AboutHerCore", "Food", "MealParser.swift")
MEAL_PARSER_TESTS = os.path.join(CORE, "Tests", "AboutHerCoreTests", "MealParserTests.swift")
