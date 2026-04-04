enum CharacterForm {
    case skinny
    case macho
    case finalForm
}

func getCharacterForm(level: Int) -> CharacterForm {
    if level >= 30 {
        return .finalForm
    } else if level >= 15 {
        return .macho
    } else {
        return .skinny
    }
}

func getDebugCharacterForm(level: Int) -> CharacterForm {
    if level >= 30 {
        return .finalForm
    } else if level >= 15 {
        return .macho
    } else {
        return .skinny
    }
}
