//
//  NorvigSolver.h
//  Solvr
//
//  Created by Chris Lewis on 12/11/14.
//  Copyright (c) 2014 Chris Lewis. All rights reserved.
//

#include <string>
#include <vector>

class Possible {
    std::vector<bool> _b;
public:
    Possible() : _b(9, true) {}
    bool   is_on(int i) const { return _b[i-1]; }
    int    count()      const { return std::count(_b.begin(), _b.end(), true); }
    void   eliminate(int i)   { _b[i-1] = false; }
    int    val()        const {
        auto it = find(_b.begin(), _b.end(), true);
        return (it != _b.end() ? 1 + (it - _b.begin()) : -1);
    }
    std::string str(int wth) const;
};

class Sudoku {
    std::vector<Possible> _cells;
    static std::vector< std::vector<int> > _group, _neighbors, _groups_of;
    
    bool     eliminate(int k, int val);
public:
    Sudoku( std::string s );
    static void init();
    
    Possible possible(int k) const { return _cells[k]; }
    bool     is_solved() const;
    bool     assign(int k, int val);
    int      least_count() const;
    void     write( std::ostream& o ) const;
    std::string   flatten() const;
};

std::unique_ptr<Sudoku> solve(std::unique_ptr<Sudoku> S);

void solve_puzzle( std::string line );