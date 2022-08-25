function error_map(s) {
        console.log(s)
    if (s === 'nil') {
        return s
    }

    const regex = /^"Expected value of type \\\"(?<type>\w+)!\\\", found null\."$/
    var found = s.match(regex)
    if (found) {
        console.log(found.groups)
        return `"Expected non-null for \"NonNull(${found.groups.type})\", got null"`
    }

    return s
}

console.log(error_map(`"Expected value of type \\"Float!\\", found null."`))