import Foundation

class MazeGenerator {
    enum CellType: Int {
        case empty = 0
        case horizontal = 1
        case vertical = 2
    }
    
    func generate(rows: Int, columns: Int) -> [[Int]] {
        var grid = Array(repeating: Array(repeating: CellType.empty.rawValue, count: columns), count: rows)
        
        // Ловушки на границах лабиринта
        for r in 0..<rows {
            for c in 0..<columns {
                if r == columns-1 || r == 0 {
                    grid[r][c] = CellType.vertical.rawValue
                }
                if c == 0 || c == rows - 1 {
                    grid[r][c] = CellType.horizontal.rawValue
                }
            }
        }
        
        // Случайные стены внутри лабиринта
        for r in 1..<rows-1 {
            for c in 1..<columns-1 {
                if Bool.random() {
                    grid[r][c] = Bool.random() ?
                        CellType.horizontal.rawValue :
                        CellType.vertical.rawValue
                }
            }
        }
        
        // Старт и финиш без элементов
        grid[1][0] = CellType.empty.rawValue
        grid[2][0] = CellType.horizontal.rawValue
        grid[rows-2][columns-1] = CellType.empty.rawValue
        grid[1][1] = CellType.empty.rawValue
        grid[rows-2][columns-2] = CellType.empty.rawValue
        
        return grid
    }
}
