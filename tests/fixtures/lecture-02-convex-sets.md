# EE 381V Lecture 2: Convex Sets (slides 1-24)

## Slides 1-5: Cones

A set C is a cone if for every x in C and every t >= 0, the point t*x is in C.
Examples: the nonnegative orthant, the set of positive semidefinite matrices.
A convex cone is a cone that is also convex; equivalently, closed under
nonnegative combinations.

## Slides 6-11: Affine sets

A set is affine if it contains the whole line through any two of its points.
Solution sets of linear equations {x : Ax = b} are affine. The affine hull of a
set is the smallest affine set containing it.

## Slides 12-18: Convex sets and the segment test

A set C is convex if for every x, y in C and every theta in [0, 1], the point
theta*x + (1 - theta)*y is in C. Geometrically: the segment between any two
points of C stays in C. Examples: disks, halfspaces, polyhedra. Non-examples:
a crescent, a ring, the union of two disjoint disks.

## Slides 19-24: Separating hyperplane theorem

If C and D are disjoint convex sets, there exists a != 0 and b such that
a^T x <= b for all x in C and a^T x >= b for all x in D. The hyperplane
{x : a^T x = b} separates them. Used in HW2 problem 3.
