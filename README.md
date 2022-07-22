# open-wos
A performant, open-source WoS-like engine.

- [Installing dependencies](#installing-dependencies)
- [How to build](#how-to-build)
- [Objects, classes, and recipes](#parts-objects-classes-and-recipes)
	- [Objects](#objects)
	- [Object recipes](#recipes)
	- [Object classes](#classes)
- [Todo list](#todo)

## Installing dependencies

1. First, install [foreman](https://github.com/Roblox/foreman)
2. Install necessary CLI tools: `foreman install`
3. Install wally dependencies: `wally install`

## How to build

1. [Install necessary dependencies](#installing-dependencies)
2. Build the project using rojo: `rojo build -o open-wos.rbxlx` (This will change in the future)

## Parts (objects), classes, and recipes

### Objects

Objects (aka parts) may be found within `src/parts`. An Object may be any valid `BasePart` or `Model`, and should have its pivot point defined at the bottom face.

### Recipes

Recipes are JSON files which define how various objects may be crafted. A valid recipe contains the following fields:
- `Results` (`Result[]`) - An array describing the `Result`s of the recipe.
- `Ingredients` (`Ingredient[]`) - An array of `Ingredient`s required to complete the recipe.

#### `Result`

A `Result` may be a `string` (the resource name, with a count of 1) or a description:
- `Resource` (`string`) - The name of the resource to be created.
- `Amount` (`number?`) - The amount of the resource to produce (default is `1`).
- `SuccessChance` (`number?`) - How likely the resource's production is to succeed, as a deciaml, `0`-`1` (default is `1`).

#### `Ingredient`

An `Ingredient` is a description of a resource to be consumed (it may *not* optionally be a `string` like `Resource`):
- `Resource` (`string`) - The name of the resource to be required.
- `Amount` (`number?`) - The amount of the resource to require (default is `1`).
- `Consume` (`boolean`) - Whether or not the resource may be consumed by the craft.
- `ConsumeChance` (`number?`) - How likely the resource's consumption is, as a deciaml, `0`-`1` (default is `1`). **Note**: Setting this to zero may result in undefined or broken behaviour. Use `Consume` to specify if this resource may be consumed.

Any number of ingredients may be listed with differing parameters, including duplicates.

### Classes

Classes are modules which describe special code for `Object`s, such as the built-in `Microcontroller` class, which controls how code is executed on a `Microcontroller` part.

They may describe methods such as `Init` to be used by the game. Additionally, they may create or utilize `UserObject`s which are extensions of `Object`s defined for "user"-code (such as within a `Microcontroller`). `UserObject`s should be used for part APIs, however a class may expose special internal methods which interact with the world in an inherently unsafe manner which should never be accessible by other potentially untrusted or unsafe code.

You may view the API reference [here (TBD)](#todo)

## TODO

- [ ] Add `Contributing.md` (guidelines for contribution).
- [ ] Minor refactoring.
- [ ] Rename references for `Parts` -> `Objects`.
- [ ] Implement user permissions APIs.
- [ ] Re-introduce `Clone` tool (Utilizing crafting system).
- [ ] Add object configuration UI.
- [ ] Add spawning & crafting menu, and recipe explorer. (UI)
- [ ] Add Microcontroller (user) APIs.
- [ ] API reference for built-in recipe, object, and build system.
- [ ] API reference for `Object` classes and `UserObject`s.
- [ ] Implement Remodel build scripts and part management.
- [ ] Implement mod support at runtime and compile time, utilizing H6x and Remodel.

## Dependencies & credits

`open-wos` is using [H6x](https://github.com/Hexcede/H6x) for code sandboxing, and has adapted a modern re-creation of the classic Roblox build tools, created by [@MaximumADHD](https://github.com/MaximumADHD).
