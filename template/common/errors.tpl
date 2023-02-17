package common

type exception struct {
	Location    string `json:"location"`
	Name        string `json:"name"`
	Description string `json:"description"`
}

func (e *exception) Error() string {
	return e.Description
}
func NewException(location, name, desc string) *exception {
	return &exception{location, name, desc}
}
