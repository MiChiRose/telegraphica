#ifndef TELEGRAPHICA_RLOTTIE_CXX11_COMPAT_H
#define TELEGRAPHICA_RLOTTIE_CXX11_COMPAT_H

#include <cstddef>
#include <memory>
#include <type_traits>
#include <utility>

#if __cplusplus < 201402L
namespace std {

template <bool Condition, typename Type = void>
using enable_if_t = typename enable_if<Condition, Type>::type;

template <typename Type, typename... Arguments>
typename enable_if<!is_array<Type>::value, unique_ptr<Type> >::type
make_unique(Arguments &&...arguments)
{
    return unique_ptr<Type>(new Type(std::forward<Arguments>(arguments)...));
}

template <typename Type>
typename enable_if<is_array<Type>::value && extent<Type>::value == 0,
                   unique_ptr<Type> >::type
make_unique(size_t count)
{
    typedef typename remove_extent<Type>::type Element;
    return unique_ptr<Type>(new Element[count]());
}

template <typename Type, typename... Arguments>
typename enable_if<extent<Type>::value != 0, void>::type
make_unique(Arguments &&...) = delete;

} // namespace std
#endif

#endif
