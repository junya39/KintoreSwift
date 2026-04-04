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
            "lv15_idle_1",
            "lv15_idle_2",
            "lv15_idle_3"
        ]
    case .finalForm:
        return [
            "lv30_idle_1",
            "lv30_idle_2",
            "lv30_idle_3"
        ]
    }
}
