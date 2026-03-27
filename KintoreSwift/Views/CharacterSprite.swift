func getCharacterImages(form: CharacterForm) -> [String] {
    switch form {
    case .skinny:
        return [
            "lv1_idle_1",
            "lv1_idle_2",
            "lv1_idle_3"
        ]
    case .macho:
        return [
            "macho_idle_1",
            "macho_idle_2",
            "macho_idle_3"
        ]
    case .finalForm:
        return [
            "lv20_idle_1",
            "lv20_idle_2",
            "lv20_idle_3"
        ]
    }
}
