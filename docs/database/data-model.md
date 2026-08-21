## Data Model

The planned database structure is:

```text
Box
 │
 ├──── 1:n ──── Animal
 │                │
 │                └──── 1:n ──── FeedingEvent
 │
 └──── 1:n ──── Sensor
```

```text
Box
├── id
├── qrId
└── createdAt
└── updatedAt
```

```text
Animal
├── id
├── boxId
├── commonName
├── latinName
├── sex
├── birthYear
├── tempMin
├── tempMax
├── humidityMin
├── humidityMax
├── picturePath
├── notes
└── createdAt
└── updatedAt
```

```text
FeedingEvent
├── id
├── animalId
├── timestamp
└── notes
```

```text
Sensor
├── id
├── boxId
├── type
├── currentValue
├── minValue
├── maxValue
└── ...
```
