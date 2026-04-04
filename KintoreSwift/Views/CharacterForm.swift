enum CharacterForm {
    case skinny
    case macho
    case finalForm
}

func getCharacterForm(level: Int) -> CharacterForm {
    evolutionStage(for: level).form
}

func getDebugCharacterForm(level: Int) -> CharacterForm {
    evolutionStage(for: level).form
}
