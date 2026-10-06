#ifndef BYONDAPI_WRAPPERS_H
#define BYONDAPI_WRAPPERS_H

#include "byondapi.h"

#if __cplusplus > 199711L
#define BYONDVALUE_FINAL final
#else
#define BYONDVALUE_FINAL
#endif

/*
	C++ wrapper classes

	Function signatures for your API should be:

		BYOND_EXPORT ByondValueResult myfunction(u4c arg_count, ByondValue args[]);

	ByondValue class:
	Wraps a CByondValue and provides reference counting.

	- Assign() fills in a new value and increfs it, calling decref on the old
	  value.
	- Attach() fills in a new value without an incref (i.e., takes ownership
	  of an existing reference), and decrefs the old.
	- Detach() clears out the value without decref, and returns what it was.
	- The CByondValue constructor uses Attach().	

	- ByondValue does not inherit from CByondValue, but wraps it. It isn't
	  allowed to have other members so it's 1:1 in memory for CByondValue. It
	  should always be possible to reinterpret_cast<> a ByondValue pointer or
	  array to CByondValue.

	ByondValueResult class:
	Exists as a convenience type to auto-detach a ByondValue when returning
	from your library function to BYOND.

	- This also does not inherit from CByondValue, just wraps it 1:1. It
	  should always be possible to reinterpret_cast<> a ByondValueResult
	  pointer or array to CByondValue.

	ByondExtException class:
	An exception thrown by the C++ wrappers when a Byondapi call fails. This
	won't be thrown unless you signal it should be thrown.

	CatchingByondExceptions class:
	Declare a var of this type at the beginning of a try block to turn
	ByondExtException throwing on.

	byondExceptionHandler var:
	Thread-local pointer to a void function(char const *) to handle exceptions.
	You can use this to define your own exception handling if you wish.
 */

class ByondExtException {
	char *str;
	public:
	ByondExtException();
	ByondExtException(char const *msg);
	ByondExtException(ByondExtException const &other);
	~ByondExtException();
	ByondExtException& operator=(ByondExtException const &other);
	char const *ToString();
};

extern void NoByondExtException(char const *e);
extern void ThrowByondExtException(char const *e);
extern THREAD_VAR void (*byondExceptionHandler)(char const *);

class CatchingByondExceptions {
	void (*old)(char const *);
	CatchingByondExceptions();
	~CatchingByondExceptions();
};

// used to auto-detach ByondValue when returning from a function
struct ByondValueResult {
	CByondValue value;
	operator CByondValue() const;
};

/*
	ByondValue is a wrapper class for CByondValue that takes care of the init,
	free, and assignment stuff for you.

	Because byondapi is limited to C structures, you can't return a ByondValue
	directly from your function. Instead, return a ByondValueResult, which will
	automatically call Detach() and return the CByondValue to the caller.
	Example:

	extern "C" BYOND_EXPORT ByondValueResult MyFunction(int n, ByondValue args[]) {
		ByondValue return_value;
		...	// function body
		// the automatic cast to ByondValueResult will detach the value
		return return_value;
	}

	The Detach() call returns a copy of the internal CByondValue while clearing
	out the ByondValue so it has nothing to clean up. The CByondValue copy
	still has to be cleaned up, which the caller (BYOND itself) will take care of
	on return.

	The args[] array is declared as ByondValue instead of CByondValue because
	it doesn't affect the call and makes the arguments easier to work with.
 */

class ByondValue BYONDVALUE_FINAL {
	public:
	CByondValue value;

	ByondValue();
	ByondValue(ByondValueType type, u4c ref);
	ByondValue(float f);
	ByondValue(char const *str);
#ifdef _STRING_
	explicit ByondValue(std::string &str);
#endif
	ByondValue(CByondValue const &src);			// attaches value without incref
	explicit ByondValue(ByondValue const &src);	// assigns value with incref
	ByondValue(ByondValue &&src);
	~ByondValue();

	ByondValue &Attach(CByondValue const &src);	// attaches value without incref; returns this
	ByondValue &Assign(CByondValue const &src);	// assigns value with incref; returns this
	CByondValue Detach();	// clears this value but returns what was in it

	ByondValue &operator=(float f);
	ByondValue &operator=(char const *str);
	ByondValue &operator=(ByondValue const &src);
	ByondValue &operator=(CByondValue const &src);
	ByondValue &operator=(ByondValue &&src);
	bool operator==(CByondValue const &v) const;
	bool operator!=(CByondValue const &v) const;
	operator bool() const;

	operator CByondValue() const;
	operator CByondValue const &() const;
	operator ByondValueResult();

	void Clear();
	ByondValueType GetType() const;

	bool IsNull() const;
	bool IsNum() const;
	bool IsStr() const;
	bool IsList() const;
	bool IsTrue() const;
	bool IsType(char const *typestr) const;

	float GetNum() const;
	u4c GetRef() const;

	void SetNum(float f);
	void SetStr(char const *str);
	void SetRef(ByondValueType type, u4c ref);

	void IncRef();
	void DecRef();
	bool TestRef();

	bool Equiv(CByondValue const &other) const;

	ByondValue &Swap(ByondValue &other);

	bool ToString(char *buf, u4c *buflen) const;	// alias for Byond_ToString()
#ifdef _STRING_
	std::string ToString() const;
	void ToString(std::string &result) const;	// this version lets you pre-allocate string space
#endif
};

char const *Byond_LastError();

/*
	All of the C++-wrapped Byond_ functions throw ByondExtException on failure.

	Functions that return true/false in the C version and take a result pointer,
	now return a result and use the exception to indicate failure.

	An exception to this is routines that require the user to allocate memory.
	Those still return true/false, but the false value only indicates additional
	memory is needed. They throw ByondExtException on a true failure.
 */

ByondValue Byond_ReadVar(CByondValue const &loc, char const *varname);
ByondValue Byond_ReadVarByStrId(CByondValue const &loc, u4c varname);
void Byond_WriteVar(CByondValue const &loc, char const *varname, CByondValue const &val);
void Byond_WriteVarByStrId(CByondValue const &loc, u4c varname, CByondValue const &val);

ByondValue Byond_CreateList(u4c len=0);
ByondValue Byond_CreateList(CByondValue const *list, u4c len);
ByondValue Byond_CreateList(ByondValue const *list, u4c len);
#ifdef _VECTOR_
ByondValue Byond_CreateList(std::vector<CByondValue> const &list);
ByondValue Byond_CreateList(std::vector<ByondValue> const &list);
#endif
ByondValue Byond_CreateDimensionalList(u4c const *sizes, u4c dimension);

// old list values will be decref'd, even if the routine fails
bool Byond_ReadList(CByondValue const &loc, ByondValue *list, u4c *len);
bool Byond_ReadListAssoc(CByondValue const &loc, ByondValue *list, u4c *len);
void Byond_WriteList(CByondValue const &loc, CByondValue const *list, u4c len);
void Byond_WriteList(CByondValue const &loc, ByondValue const *list, u4c len);
#ifdef _VECTOR_
void Byond_ReadList(CByondValue const &loc, std::vector<ByondValue> &list);
std::vector<ByondValue> Byond_ReadList(CByondValue const &loc);
void Byond_ReadListAssoc(CByondValue const &loc, std::vector<ByondValue> &list);
std::vector<ByondValue> Byond_ReadListAssoc(CByondValue const &loc);
void Byond_WriteList(CByondValue const &loc, std::vector<CByondValue> const &list);
void Byond_WriteList(CByondValue const &loc, std::vector<ByondValue> const &list);
#endif

ByondValue Byond_ReadListIndex(CByondValue const &loc, CByondValue const &idx);
void Byond_WriteListIndex(CByondValue const &loc, CByondValue const &idx, CByondValue const &val);

ByondValue Byond_ReadPointer(CByondValue const &ptr);
void Byond_WritePointer(CByondValue const &ptr, CByondValue const &val);

ByondValue Byond_CallProc(CByondValue const &src, char const *name, CByondValue const *arg, u4c arg_count);
ByondValue Byond_CallProc(CByondValue const &src, char const *name, ByondValue const *arg, u4c arg_count);
ByondValue Byond_CallProcByStrId(CByondValue const &src, u4c name, CByondValue const *arg, u4c arg_count);
ByondValue Byond_CallProcByStrId(CByondValue const &src, u4c name, ByondValue const *arg, u4c arg_count);

ByondValue Byond_CallGlobalProc(char const *name, CByondValue const *arg, u4c arg_count);
ByondValue Byond_CallGlobalProc(char const *name, ByondValue const *arg, u4c arg_count);
ByondValue Byond_CallGlobalProcByStrId(u4c name, CByondValue const *arg, u4c arg_count);
ByondValue Byond_CallGlobalProcByStrId(u4c name, ByondValue const *arg, u4c arg_count);

bool Byond_ToString(CByondValue const &src, char *buf, u4c *buflen);
#ifdef _STRING_
std::string Byond_ToString(CByondValue const &src);
void Byond_ToString(CByondValue const &src, std::string &result);	// this version allows you to pre-allocate space
#endif

bool Byond_Return(CByondValue const &waiting_proc, CByondValue const &retval);

bool Byond_Block(CByondXYZ const &corner1, CByondXYZ const &corner2, CByondValue *list, u4c *len);
#ifdef _VECTOR_
void Byond_Block(CByondXYZ const &corner1, CByondXYZ const &corner2, std::vector<ByondValue> &list);
std::vector<ByondValue> Byond_Block(CByondXYZ const &corner1, CByondXYZ const &corner2);
#endif

bool ByondValue_IsType(ByondValue const &src, char const *typestr);

ByondValue Byond_Length(ByondValue const &src);
ByondValue Byond_Locate(ByondValue const &type);
ByondValue Byond_LocateIn(ByondValue const &type, ByondValue const &list);
ByondValue Byond_LocateXYZ(CByondXYZ const &xyz);

ByondValue Byond_New(ByondValue const &src, CByondValue const *arg, u4c arg_count);
ByondValue Byond_New(ByondValue const &src, ByondValue const *arg, u4c arg_count);
ByondValue Byond_NewArglist(ByondValue const &src, ByondValue const &arglist);

u4c Byond_Refcount(ByondValue const &src);
CByondXYZ Byond_XYZ(ByondValue const &src);
CByondPixLoc Byond_PixLoc(ByondValue const &src);
CByondPixLoc Byond_BoundPixLoc(ByondValue const &src, u1c dir);

#endif
