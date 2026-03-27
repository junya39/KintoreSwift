enum CharacterForm {
    case skinny
    case macho
    case finalForm
}

func getCharacterForm(level: Int) -> CharacterForm {
    if level >= 20 {
        return .finalForm
    } else if level >= 10 {
        return .macho
    } else {
        return .skinny
    }
}

func getDebugCharacterForm(level: Int) -> CharacterForm {
    if level >= 20 {
        return .finalForm
    } else if level >= 10 {
        return .macho
    } else {
        return .skinny
    }
}
